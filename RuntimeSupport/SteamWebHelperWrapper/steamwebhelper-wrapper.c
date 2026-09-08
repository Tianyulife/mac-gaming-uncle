/*
 * SPDX-License-Identifier: MIT
 *
 * Copyright (c) 2026 notpop
 * Copyright (c) 2026 Indie contributors
 *
 * Derived from notpop/steam-on-m1-wine's Steam WebHelper wrapper.
 * It forces Steam CEF into CPU rasterization and a single process to avoid
 * black/transparent browser surfaces in Wine on Apple Silicon.
 */

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <stdlib.h>
#include <wchar.h>
#include "bridge-pipe.h"

#define REAL_BINARY L"steamwebhelper_real.exe"
#define EXTRA_FLAGS L"--disable-gpu --in-process-gpu --no-sandbox"
#define WRAPPER_MARKER "INDIE_STEAM_WEBHELPER_WRAPPER_V1"

static const wchar_t *forwarded_arguments(void)
{
    const wchar_t *cursor = GetCommandLineW();
    int quoted = 0;
    if (!cursor) return L"";
    while (*cursor) {
        if (*cursor == L'\"') quoted = !quoted;
        else if (*cursor == L' ' && !quoted) break;
        ++cursor;
    }
    while (*cursor == L' ') ++cursor;
    return cursor;
}

int wmain(void)
{
    SetEnvironmentVariableA("INDIE_STEAM_WEBHELPER_WRAPPER", WRAPPER_MARKER);
    wchar_t self[MAX_PATH];
    DWORD length = GetModuleFileNameW(NULL, self, MAX_PATH);
    if (length == 0 || length >= MAX_PATH) return 1;

    wchar_t *slash = wcsrchr(self, L'\\');
    if (!slash) return 2;
    *(slash + 1) = L'\0';

    size_t real_capacity = wcslen(self) + wcslen(REAL_BINARY) + 1;
    wchar_t *real = (wchar_t *)calloc(real_capacity, sizeof(wchar_t));
    if (!real) return 3;
    wcscpy(real, self);
    wcscat(real, REAL_BINARY);

    const wchar_t *tail = forwarded_arguments();
    wchar_t bridge_flags[256]=L"";
    wchar_t display_flags[128]=L"";
    if(!wcsstr(tail,L"--type="))mgu_display_flags(self,display_flags,128);
    HANDLE child_read=NULL,child_write=NULL;
    BOOL bridge = !wcsstr(tail,L"--type=") &&
        mgu_create_pipes(self,bridge_flags,256,&child_read,&child_write);
    size_t command_capacity = wcslen(real) + wcslen(EXTRA_FLAGS) + wcslen(tail) + wcslen(bridge_flags) + wcslen(display_flags) + 12;
    wchar_t *command = (wchar_t *)calloc(command_capacity, sizeof(wchar_t));
    if (!command) { free(real); return 4; }
    _snwprintf(command, command_capacity, L"\"%ls\" %ls %ls %ls %ls", real, EXTRA_FLAGS, tail,bridge_flags,display_flags);

    STARTUPINFOW startup;
    PROCESS_INFORMATION process;
    ZeroMemory(&startup, sizeof(startup));
    ZeroMemory(&process, sizeof(process));
    startup.cb = sizeof(startup);

    BOOL launched = CreateProcessW(real, command, NULL, NULL, TRUE, 0, NULL, NULL, &startup, &process);
    if(child_read)CloseHandle(child_read);
    if(child_write)CloseHandle(child_write);
    free(command);
    free(real);
    if (!launched) { mgu_close_pipes(); return 5; }
    HANDLE relay=bridge ? CreateThread(NULL,0,mgu_relay,NULL,0,NULL) : NULL;
    if(*display_flags){mgu_ui_pid=process.dwProcessId;HANDLE fit=CreateThread(NULL,0,mgu_fit_windows,NULL,0,NULL);if(fit)CloseHandle(fit);}

    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exit_code = 1;
    GetExitCodeProcess(process.hProcess, &exit_code);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    // The child has exited; its pipe closes and the relay removes its heartbeat.
    if(relay){WaitForSingleObject(relay,2000);CloseHandle(relay);}
    mgu_close_pipes();
    return (int)exit_code;
}
