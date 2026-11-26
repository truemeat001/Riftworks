// Offline graph diagnostic using exact exported Godot JS Bus class; no real WebAudio,
// browser or sound claim. Run node script path/to/index.js.
const fs=require('fs'),assert=require('assert');
const s=fs.readFileSync(process.argv[2],'utf8');
const first=s.indexOf('Bus:class Bus'), last=s.indexOf(',sampleFinishedCallback:',first);
assert(first>=0&&last>first,'exported Bus class expected');
const classText=s.slice(first+4,last);
class MockGain {constructor(){this.gain={value:1};this.outputs=[];} connect(n){this.outputs.push(n);return n;} disconnect(){this.outputs=[];}}
const GodotAudio={buses:[],busSolo:null,ctx:{createGain:()=>new MockGain(),destination:new MockGain()}};
GodotAudio.Bus=eval('('+classText+')');
const B=GodotAudio.Bus;
const parent=[null,0,1,1,1,0,0];
function connected(n,seen=new Set()){
 if(n===GodotAudio.ctx.destination)return true;
 if(seen.has(n))return false;seen.add(n);
 return n.outputs.some(x=>connected(x,seen));
}
function graph(useCount){
 GodotAudio.buses=[];B.setCount(1);const master=B.getBus(0);
 let physical=[master];
 if(useCount){B.setCount(7);physical=GodotAudio.buses.slice();}
 else for(let i=1;i<7;i++){
  B.addAt(-1);
  const newBus=GodotAudio.buses.find(b=>!physical.includes(b));physical.push(newBus);
  B.getBus(i).setSend(B.getBus(parent[i]));
 }
 for(let i=1;i<7;i++)B.getBus(i).setSend(B.getBus(parent[i]));
 return {array:GodotAudio.buses.map(x=>physical.indexOf(x)),dest:GodotAudio.buses.map(x=>connected(x.getInputNode())),masterStillAtZero:master===B.getBus(0)};
}
const old=graph(false),fixed=graph(true);
console.log(JSON.stringify({old_dynamic_append:old,fixed_count_first:fixed}));
assert(!old.masterStillAtZero && old.dest.every(x=>!x),'old exact graph disconnected');
assert(fixed.masterStillAtZero && fixed.dest.every(x=>x),'count-first exact graph all destinations');
