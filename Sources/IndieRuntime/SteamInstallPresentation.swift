import Foundation

/// Reversible presentation guard, scoped to the client's popup manager. Steam's
/// popup factory already creates hidden windows; block the later Show/Focus calls
/// before rendering, rather than racing them with a hide timer.
enum SteamInstallPresentation {
    static let script = #"""
    (()=>{
      if(window.__mguInstallPresentation?.version===1)return;
      const manager=window.g_PopupManager;
      const factory=manager?.constructor;
      if(!manager||typeof factory.CreatePopup!=='function'||typeof manager.AddTrackedPopup!=='function')
        throw Error('Unsupported Steam popup manager');
      const state={version:1,until:0,bindings:[],popups:[],blocked:0,timer:null};
      const active=()=>Date.now()<state.until;
      const wrap=(object,key)=>{
        if(!object||typeof object[key]!=='function'||state.bindings.some(x=>x.object===object&&x.key===key))return;
        const original=object[key];
        const replacement=function(...args){
          if(active()){state.blocked++;return;}
          return Reflect.apply(original,object,args);
        };
        object[key]=replacement;
        if(object[key]!==replacement)throw Error('Steam presentation API cannot be guarded');
        state.bindings.push({object,key,original,replacement});
      };
      const protectWindow=w=>{
        if(!w||w.closed)return;
        wrap(w.SteamClient?.Window,'ShowWindow');
        wrap(w.SteamClient?.Window,'BringToFront');
        wrap(w,'focus');
      };
      const protectPopup=p=>{
        if(!p||state.popups.some(x=>x.popup===p))return;
        state.popups.push({popup:p,hidden:p.m_bCreateHidden});
        p.m_bCreateHidden=true;
        protectWindow(p.window||p.m_popup);
      };
      state.end=(showPending=false)=>{
        state.until=0;
        clearInterval(state.timer);state.timer=null;
        if(state.createWrapper&&factory.CreatePopup===state.createWrapper)factory.CreatePopup=state.createOriginal;
        if(state.addWrapper&&manager.AddTrackedPopup===state.addWrapper)manager.AddTrackedPopup=state.addOriginal;
        for(const b of state.bindings){try{if(b.object[b.key]===b.replacement)b.object[b.key]=b.original;}catch{}}
        for(const p of state.popups){try{
          p.popup.m_bCreateHidden=p.hidden;
          if(showPending&&!/^contextmenu_/.test(p.popup.m_strName||''))p.popup.Show();
        }catch{}}
        state.bindings=[];state.popups=[];
        return true;
      };
      state.touch=()=>{if(state.until)state.until=Date.now()+20000;return true;};
      state.begin=()=>{
        if(active())return state.touch();
        state.end();state.until=Date.now()+20000;state.blocked=0;
        state.createOriginal=factory.CreatePopup;
        state.addOriginal=manager.AddTrackedPopup;
        state.createWrapper=function(name,params){
          const result=Reflect.apply(state.createOriginal,this,[name,params]);
          if(active())protectWindow(result?.popup);
          return result;
        };
        state.addWrapper=function(p){
          if(active())protectPopup(p);
          return Reflect.apply(state.addOriginal,this,[p]);
        };
        try {
          factory.CreatePopup=state.createWrapper;
          manager.AddTrackedPopup=state.addWrapper;
          for(const p of manager.GetPopups()){
            if(/^SP Desktop(?:_|$)/.test(p.m_strName||''))protectPopup(p);
          }
          state.timer=setInterval(()=>{if(!active())state.end();},1000);
          return true;
        } catch(e){state.end();throw e;}
      };
      window.__mguInstallPresentation=state;
    })()
    """#
}
