import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=readFileSync(new URL('../Sources/IndieRuntime/SteamInstallPresentation.swift',import.meta.url),'utf8');
const script=source.match(/#"""([\s\S]*?)"""#/)[1];
let visible=0,now=0,tick;
const makeWindow=()=>({closed:false,focus(){visible++},SteamClient:{Window:{ShowWindow(){visible++},BringToFront(){visible++}}}});
const main={m_strName:'SP Desktop_uid0',m_bCreateHidden:true,window:makeWindow(),Show(){this.window.SteamClient.Window.BringToFront()}};
class Manager {
 constructor(){this.popups=[main];}
 static CreatePopup(){return {popup:makeWindow(),element:{}};}
 AddTrackedPopup(p){this.popups.push(p);}
 GetPopups(){return this.popups.values();}
}
const manager=new Manager();
const originalFactory=Manager.CreatePopup;
const window={g_PopupManager:manager};
vm.runInNewContext(script,{window,Date:{now:()=>now},setInterval:f=>(tick=f,1),clearInterval(){}});
const guard=window.__mguInstallPresentation;
guard.begin();
main.Show();assert.equal(visible,0,'Existing main window must not grab focus');
const created=Manager.CreatePopup('install',{});
const modal={m_strName:'install',m_bCreateHidden:false,window:created.popup,Show(){this.window.SteamClient.Window.ShowWindow()}};
manager.AddTrackedPopup(modal);
assert.equal(modal.m_bCreateHidden,true);
modal.Show();created.popup.focus();assert.equal(visible,0,'New popup must be blocked BEFORE visibility');
assert.ok(guard.blocked>=3);
guard.end(true);assert.equal(Manager.CreatePopup,originalFactory);
assert.equal(modal.m_bCreateHidden,false);assert.ok(visible>=2,'Explicit user opening must restore presentation');
guard.begin();now=21000;tick();assert.equal(Manager.CreatePopup,originalFactory,'Lease expiry restores hooks');
const before=visible;main.Show();assert.equal(visible,before+1);
console.log('PASS: pre-display guard, focus guard, native-window restoration, explicit opening, lease expiry');
