/* SPDX-License-Identifier: MIT
 * Private filesystem mailbox -> inherited CEF pipes. No TCP debug listener.
 * The host creates mgu-bridge with mode 0700 before enabling this transport.
 * This is an OS-user boundary, not protection against code running as that user.
 */
#include <stdio.h>
#include <stdint.h>

#define MGU_MESSAGE_LIMIT (1024 * 1024)
static HANDLE mgu_read = NULL, mgu_write = NULL;
static wchar_t mgu_directory[MAX_PATH];
static double mgu_ui_scale=1.0;
static DWORD mgu_ui_pid=0;
static HWND mgu_sized_windows[32];
static unsigned int mgu_sized_count=0;

static void mgu_display_flags(const wchar_t *directory,wchar_t *flags,size_t capacity) {
    wchar_t file[MAX_PATH];swprintf(file,MAX_PATH,L"%lsmgu-bridge\\display.txt",directory);
    FILE *f=_wfopen(file,L"rb");int width=0,height=0;
    if(!f)return;
    int count=fscanf(f,"%d %d",&width,&height);fclose(f);
    if(count!=2||width<640||width>16384||height<480||height>16384)return;
    // Compare Wine's desktop coordinate space to macOS logical points, without
    // changing Wine Retina/DPI registry settings shared with games.
    DEVMODEW mode={0};mode.dmSize=sizeof(mode);
    // GetSystemMetrics can be DPI-virtualized in this wrapper, while CEF uses
    // physical pixels. EnumDisplaySettings is explicitly not DPI-virtualized.
    int physical_width=GetSystemMetrics(SM_CXSCREEN);
    if(EnumDisplaySettingsW(NULL,ENUM_CURRENT_SETTINGS,&mode)&&mode.dmPelsWidth)
        physical_width=(int)mode.dmPelsWidth;
    mgu_ui_scale=(double)physical_width/width;
    if(mgu_ui_scale<1.0)mgu_ui_scale=1.0;
    if(mgu_ui_scale>3.0)mgu_ui_scale=3.0;
    swprintf(flags,capacity,L"--force-device-scale-factor=%.2f",mgu_ui_scale);
}

static BOOL CALLBACK mgu_fit_window(HWND window,LPARAM ignored) {
    (void)ignored;DWORD pid=0;GetWindowThreadProcessId(window,&pid);
    if(mgu_sized_count>=32)return TRUE;
    if(pid!=mgu_ui_pid||GetWindow(window,GW_OWNER))return TRUE;
    wchar_t title[128];GetWindowTextW(window,title,128);
    if(wcscmp(title,L"Steam")!=0)return TRUE;
    for(unsigned int i=0;i<mgu_sized_count;++i)if(mgu_sized_windows[i]==window)return TRUE;
    RECT rect;if(!GetWindowRect(window,&rect)||rect.right-rect.left<400)return TRUE;
    MONITORINFO monitor={0};monitor.cbSize=sizeof(monitor);
    if(!GetMonitorInfoW(MonitorFromWindow(window,MONITOR_DEFAULTTONEAREST),&monitor))return TRUE;
    RECT work=monitor.rcWork;int margin=(int)(24*mgu_ui_scale);
    int width=min((int)(1200*mgu_ui_scale),work.right-work.left-2*margin);
    int height=min((int)(800*mgu_ui_scale),work.bottom-work.top-2*margin);
    if(width<400||height<300)return TRUE;
    if(rect.right-rect.left>width+margin||rect.bottom-rect.top>height+margin||
       rect.left<work.left||rect.top<work.top||rect.right>work.right||rect.bottom>work.bottom){
        if(IsZoomed(window))ShowWindow(window,SW_SHOWNOACTIVATE);
        SetWindowPos(window,NULL,work.left+(work.right-work.left-width)/2,
            work.top+(work.bottom-work.top-height)/2,width,height,SWP_NOACTIVATE|SWP_NOZORDER);
    }
    if(mgu_sized_count<32)mgu_sized_windows[mgu_sized_count++]=window;
    return TRUE;
}

static DWORD WINAPI mgu_fit_windows(void *unused) {
    (void)unused;
    // The fitted size is in physical pixels, matching CEF's scale. Opt only
    // this helper thread out of DPI virtualization; do not change the bottle.
    typedef HANDLE (WINAPI *SetThreadDPI)(HANDLE);
    SetThreadDPI set_dpi=(SetThreadDPI)(void*)GetProcAddress(GetModuleHandleW(L"user32.dll"),"SetThreadDpiAwarenessContext");
    if(set_dpi)set_dpi((HANDLE)(intptr_t)-4);
    // Once per main window; never fight subsequent manual resizing/maximization.
    for(;;){EnumWindows(mgu_fit_window,0);Sleep(1000);}
    return 0;
}

static void mgu_close_pipes(void) {
    if(mgu_read) CloseHandle(mgu_read);
    if(mgu_write) CloseHandle(mgu_write);
    mgu_read=mgu_write=NULL;
}

static BOOL mgu_create_pipes(const wchar_t *directory, wchar_t *flags, size_t capacity,
                             HANDLE *child_read, HANDLE *child_write) {
    wchar_t root[MAX_PATH];
    if(swprintf(root,MAX_PATH,L"%lsmgu-bridge",directory)<0)return FALSE;
    DWORD attrs=GetFileAttributesW(root);
    // Only the native application may enable the private mailbox directory.
    if(attrs==INVALID_FILE_ATTRIBUTES || !(attrs&FILE_ATTRIBUTE_DIRECTORY) ||
       (attrs&FILE_ATTRIBUTE_REPARSE_POINT))return FALSE;
    swprintf(mgu_directory,MAX_PATH,L"%ls\\%lu-%llu",root,GetCurrentProcessId(),GetTickCount64());
    if(!CreateDirectoryW(mgu_directory,NULL))return FALSE;
    SECURITY_ATTRIBUTES sa={sizeof(sa),NULL,TRUE};
    if(!CreatePipe(child_read,&mgu_write,&sa,65536) ||
       !CreatePipe(&mgu_read,child_write,&sa,65536)) {
        mgu_close_pipes();
        if(*child_read)CloseHandle(*child_read);
        if(*child_write)CloseHandle(*child_write);
        *child_read=*child_write=NULL;return FALSE;
    }
    SetHandleInformation(mgu_read,HANDLE_FLAG_INHERIT,0);
    SetHandleInformation(mgu_write,HANDLE_FLAG_INHERIT,0);
    swprintf(flags,capacity,L"--remote-debugging-pipe --remote-debugging-io-pipes=%llu,%llu",
        (unsigned long long)(ULONG_PTR)*child_read,(unsigned long long)(ULONG_PTR)*child_write);
    return TRUE;
}

static BOOL mgu_request_name(const wchar_t *name) {
    int count=0;while(name[count]>=L'0'&&name[count]<=L'9')++count;
    return count>0&&count<=10&&wcscmp(name+count,L".request")==0;
}

static DWORD WINAPI mgu_relay(void *unused) {
    (void)unused;
    char *buffer=malloc(MGU_MESSAGE_LIMIT);size_t used=0;BOOL oversized=FALSE;
    if(!buffer)return 1;
    wchar_t ready[MAX_PATH],pattern[MAX_PATH];
    swprintf(ready,MAX_PATH,L"%ls\\ready",mgu_directory);
    swprintf(pattern,MAX_PATH,L"%ls\\*.request",mgu_directory);
    ULONGLONG heartbeat=0;
    for(;;){
        if(GetTickCount64()-heartbeat>1000){
            FILE *f=_wfopen(ready,L"wb");if(f){fputs("MGU_PIPE_V1",f);fclose(f);}
            heartbeat=GetTickCount64();
        }
        WIN32_FIND_DATAW entry;HANDLE search=FindFirstFileW(pattern,&entry);
        if(search!=INVALID_HANDLE_VALUE){
            do {
                if(!mgu_request_name(entry.cFileName)||entry.nFileSizeHigh||entry.nFileSizeLow>32768||
                   entry.dwFileAttributes&(FILE_ATTRIBUTE_DIRECTORY|FILE_ATTRIBUTE_REPARSE_POINT))continue;
                wchar_t file[MAX_PATH];swprintf(file,MAX_PATH,L"%ls\\%ls",mgu_directory,entry.cFileName);
                FILE *f=_wfopen(file,L"rb");if(!f)continue;
                char request[32769];size_t size=fread(request,1,32768,f);fclose(f);DeleteFileW(file);
                if(!size||memchr(request,0,size))continue;
                request[size]=0;DWORD written=0;
                if(!WriteFile(mgu_write,request,(DWORD)size+1,&written,NULL)||written!=size+1)goto done;
            }while(FindNextFileW(search,&entry));
            FindClose(search);
        }
        DWORD available=0;
        if(!PeekNamedPipe(mgu_read,NULL,0,NULL,&available,NULL))break;
        while(available){
            char chunk[8192];DWORD count=0;
            if(!ReadFile(mgu_read,chunk,min(available,(DWORD)sizeof(chunk)),&count,NULL))goto done;
            for(DWORD i=0;i<count;++i){
                if(chunk[i]){
                    if(used+1>=MGU_MESSAGE_LIMIT)oversized=TRUE;
                    if(!oversized)buffer[used++]=chunk[i];
                    continue;
                }
                if(oversized){used=0;oversized=FALSE;continue;}
                buffer[used]=0;
                // Chromium serializes response id first; events are deliberately discarded.
                unsigned long id=0;int offset=0;
                if(sscanf(buffer,"{\"id\":%lu%n",&id,&offset)==1 && id>0 &&
                   (buffer[offset]==','||buffer[offset]=='}')){
                    wchar_t temp[MAX_PATH],target[MAX_PATH];
                    swprintf(temp,MAX_PATH,L"%ls\\%lu.partial",mgu_directory,id);
                    swprintf(target,MAX_PATH,L"%ls\\%lu.response",mgu_directory,id);
                    FILE *f=_wfopen(temp,L"wb");
                    if(f){fwrite(buffer,1,used,f);fclose(f);MoveFileExW(temp,target,MOVEFILE_REPLACE_EXISTING);}
                }
                used=0;
            }
            if(!PeekNamedPipe(mgu_read,NULL,0,NULL,&available,NULL))goto done;
        }
        Sleep(50);
    }
done:
    DeleteFileW(ready);free(buffer);return 0;
}
