const test = require('node:test');
const assert = require('node:assert/strict');
const {axisPositions,sectionGeometry,inlineSettingsDelta,moveLayoutEntry,addLayoutEntry,removeLayoutEntry,replaceEntrySettings,entrySettings,readableForeground,contrastRatio,intersectRect} = require('../BarModel.js');
const settings = {mode:'islands',outerMargin:12,sectionPadding:16,widgetSpacing:8};
function bounded(result,length) {
  for (const interval of Object.values(result.islands)) {
    assert.ok(Number.isFinite(interval.start) && interval.start>=0);
    assert.ok(Number.isFinite(interval.extent) && interval.extent>=0);
    assert.ok(interval.start+interval.extent <= length+1e-8);
  }
  const painted=Object.values(result.islands).filter(g=>g.extent>0).sort((a,b)=>a.start-b.start);
  for(let i=1;i<painted.length;i++)assert.ok(painted[i-1].start+painted[i-1].extent<=painted[i].start+1e-8,'painted sections overlap');
  for(const group of Object.values(result.groups))for(const field of ['start','extent','contentExtent','initialOffset'])assert.ok(Number.isFinite(group[field])&&group[field]>=0);
}
test('axis flow retains native extents and adds gaps only between drawn entries',()=>{
  assert.deepEqual(axisPositions([0,20,0,30,0],8),{positions:[0,0,20,28,58],extent:58});
  assert.deepEqual(axisPositions([NaN,-5,Infinity,20,'30'],NaN),{positions:[0,0,0,0,20],extent:20});
});
test('ordinary center stays at physical midpoint despite unequal sides',()=>{
  const result=sectionGeometry(1000,{left:[210,30],center:[32,90],right:[32]},-1,settings);
  bounded(result,1000);
  assert.equal(result.islands.center.start+result.islands.center.extent/2,500);
  assert.equal(result.groups.center.contentExtent,130);
  assert.equal(result.groups.centerAnchor.extent,0);
});
test('section breathing room never inflates the gaps inside anchored content',()=>{
  const result=sectionGeometry(500,{left:[300],center:[20,30,20],right:[300]},1,{...settings,widgetSpacing:6,groupSpacing:24});
  bounded(result,500);
  const before=result.groups.centerBefore, anchor=result.groups.centerAnchor, after=result.groups.centerAfter;
  assert.equal(anchor.start+anchor.extent/2,250);
  assert.equal(anchor.start-before.start-before.extent,6);
  assert.equal(after.start-anchor.start-anchor.extent,6);
  assert.equal(result.islands.center.start-result.islands.left.start-result.islands.left.extent,24);
  assert.equal(result.islands.right.start-result.islands.center.start-result.islands.center.extent,24);
});
test('selected drawn anchor stays physically centered with asymmetric capped wings',()=>{
  const result=sectionGeometry(1000,{left:[180],center:[600,32,500],right:[32]},1,settings);
  bounded(result,1000);
  const anchor=result.groups.centerAnchor;
  assert.equal(anchor.start+anchor.extent/2,500);
  assert.equal(result.groups.centerBefore.contentExtent,600);
  assert.equal(result.groups.centerAfter.contentExtent,500);
  assert.ok(result.groups.centerBefore.initialOffset>0,'before starts at tail beside anchor');
  assert.equal(result.groups.centerAfter.initialOffset,0,'after starts beside anchor');
});
test('hidden or oversized anchor falls back to centered native-size scrolling',()=>{
  for(const center of [[100,0,100],[100,1500,100]]) {
    const result=sectionGeometry(500,{left:[80],center,right:[80]},1,settings);
    bounded(result,500);
    assert.equal(result.groups.centerAnchor.extent,0);
    assert.equal(result.islands.center.start+result.islands.center.extent/2,250);
    assert.equal(result.groups.center.contentExtent,axisPositions(center,8).extent);
    if(center[1]>0)assert.ok(result.diagnostics.some(d=>d.includes('anchor')));
  }
});
test('a fitting anchor falls back when its nonempty wings have no usable viewport',()=>{
  const result=sectionGeometry(1000,{left:[32],center:[32,868,32],right:[32]},1,{mode:'islands',outerMargin:6,sectionPadding:8,widgetSpacing:4});
  assert.equal(result.groups.centerAnchor.extent,0);
  assert.equal(result.groups.center.contentExtent,940);
  assert.ok(result.groups.center.extent>24);
  assert.equal(result.groups.center.start+result.groups.center.extent/2,500);
  assert.ok(result.diagnostics.some(d=>d.includes('neighboring')));
});
test('foreground maintains readable contrast on saturated and neutral backgrounds',()=>{
  const preferred={r:0.9,g:0.9,b:0.9};
  for(const background of [{r:0,g:0,b:1},{r:1,g:1,b:0},{r:0.5,g:0.5,b:0.5},{r:0,g:0,b:0},{r:1,g:1,b:1}]) {
    const chosen=readableForeground(background,preferred);
    const rgb=chosen==='#000000' ? {r:0,g:0,b:0} : chosen==='#ffffff' ? {r:1,g:1,b:1} : chosen;
    assert.ok(contrastRatio(background,rgb)>=4.5);
  }
  assert.equal(readableForeground({r:0,g:0,b:1},preferred),preferred);
  assert.equal(readableForeground({r:1,g:1,b:0},preferred),'#000000');
});
test('drawn intervals exclude completely clipped slots and trim partial slots',()=>{
  const viewport={x:50,y:10,width:100,height:30};
  assert.equal(intersectRect({x:151,y:10,width:30,height:30},viewport),null);
  assert.deepEqual(intersectRect({x:40,y:10,width:30,height:30},viewport),{x:50,y:10,width:20,height:30});
  assert.equal(intersectRect({x:50,y:41,width:30,height:30},viewport),null);
});
test('overflow exposes native scroll ranges and preserves outer-end side alignment',()=>{
  const result=sectionGeometry(1000,{left:[900],center:[1000],right:[1200]},-1,settings);
  bounded(result,1000);
  assert.equal(result.groups.left.contentExtent,900);
  assert.equal(result.groups.right.contentExtent,1200);
  assert.ok(result.groups.left.extent>=48);
  assert.equal(result.groups.left.initialOffset,0);
  assert.equal(result.groups.right.initialOffset,1200-(result.groups.right.extent-24));
  assert.equal(result.groups.center.initialOffset,(1000-(result.groups.center.extent-24))/2);
});
test('empty center divides side budgets without drawing an empty island',()=>{
  const result=sectionGeometry(300,{left:[500],center:[0,0],right:[500]},-1,settings);
  bounded(result,300);
  assert.equal(result.islands.center.extent,0);
  assert.ok(result.islands.left.start+result.islands.left.extent+8<=result.islands.right.start);
  assert.deepEqual(result.groups.center,{start:0,extent:0,contentExtent:0,initialOffset:0});
});
test('tiny, invalid and docked axes remain finite and nonoverlapping',()=>{
  for(const length of [0,1,12,24,64,100,500,3440])for(const anchor of [-1,0,1,2])for(const mode of ['docked','floating-bar','islands']) {
    const result=sectionGeometry(length,{left:[200,0,60],center:[400,32,800],right:[900]},anchor,{...settings,mode});
    bounded(result,length);
    if(mode==='docked')assert.equal(result.islands.left.start,0);
  }
  bounded(sectionGeometry(NaN,{left:[NaN],center:[Infinity],right:[-1]},-1,settings),0);
});
test('inline settings changes preserve identity while structural and ambiguous edits rebuild',()=>{
  const current={left:[{id:'omarchy.audio',vendor:{a:1}}],center:[],right:[]};
  const next={left:[{id:'omarchy.audio',vendor:{a:2}}],center:[],right:[]};
  assert.deepEqual(inlineSettingsDelta(current,next),[{region:'left',index:0,entry:next.left[0]}]);
  assert.equal(inlineSettingsDelta(current,{left:[],center:next.left,right:[]}),null);
  assert.equal(inlineSettingsDelta({...current,right:current.left},{...next,right:current.left}),null);
});

function editorLayout() {
  return {
    left: ['omarchy.audio', {id:'missing.vendor', nested:{items:[{enabled:true}]}}],
    center: ['omarchy.clock'],
    right: [{id:'omarchy.power', showPercentage:true}],
    vendor: {untouched:['custom']}
  };
}
function rejected(result, original) {
  assert.equal(result.layout, original);
  assert.equal(typeof result.error, 'string');
  assert.notEqual(result.error, '');
}
test('moves preserve stale entries and destination indices refer to after removal',()=>{
  const original=editorLayout();
  const cross=moveLayoutEntry(original,'left',1,'center',1);
  assert.equal(cross.error,'');
  assert.deepEqual(cross.layout,{...original,left:['omarchy.audio'],center:['omarchy.clock',original.left[1]]});
  assert.deepEqual(original,editorLayout());
  const within={left:['a','b','c','d'],center:[],right:[]};
  assert.deepEqual(moveLayoutEntry(within,'left',0,'left',3).layout.left,['b','c','d','a']);
  assert.deepEqual(moveLayoutEntry(within,'left',3,'left',0).layout.left,['d','a','b','c']);
  assert.deepEqual(moveLayoutEntry(within,'left',1,'left',2).layout.left,['a','c','b','d']);
  rejected(moveLayoutEntry(within,'left',0,'left',4),within);
  const singleton={left:['a'],center:[],right:[]};
  assert.deepEqual(moveLayoutEntry(singleton,'left',0,'left',0).layout,singleton);
  assert.deepEqual(moveLayoutEntry(singleton,'left',0,'center',0).layout,{left:[],center:['a'],right:[]});
});
test('entry operations reject malformed sections, entries and strict index boundaries',()=>{
  const original=editorLayout();
  for(const section of ['unknown','__proto__','constructor',null]) {
    rejected(moveLayoutEntry(original,section,0,'right',0),original);
    rejected(moveLayoutEntry(original,'left',0,section,0),original);
    rejected(addLayoutEntry(original,section,'new',{}),original);
    rejected(removeLayoutEntry(original,section,0),original);
    rejected(replaceEntrySettings(original,section,0,{}),original);
  }
  for(const index of [-1,0.5,NaN,Infinity,'0',null,2]) {
    rejected(moveLayoutEntry(original,'left',index,'center',0),original);
    rejected(removeLayoutEntry(original,'left',index),original);
    rejected(replaceEntrySettings(original,'left',index,{}),original);
  }
  for(const index of [-1,0.5,NaN,Infinity,'0',null,2])
    rejected(moveLayoutEntry(original,'left',0,'center',index),original);
  for(const layout of [null,[],{left:[],center:[]},{left:[],center:{},right:[]},
      {left:[null],center:[],right:[]},{left:[{}],center:[],right:[]},
      {left:[{id:7}],center:[],right:[]},{left:[' '],center:[],right:[]},
      {left:[Object.create({id:'inherited'})],center:[],right:[]}]) {
    rejected(moveLayoutEntry(layout,'left',0,'center',0),layout);
    rejected(addLayoutEntry(layout,'right','new',{}),layout);
    rejected(removeLayoutEntry(layout,'left',0),layout);
    rejected(replaceEntrySettings(layout,'left',0,{}),layout);
  }
  for(const id of ['', ' ', null, 3, {}]) rejected(addLayoutEntry(original,'left',id,{}),original);
  for(const metadata of [null,[],true]) rejected(addLayoutEntry(original,'left','new',metadata),original);
});
test('single-instance additions check raw IDs throughout all sections without deleting duplicates',()=>{
  const layout={left:['singleton'],center:[{id:'singleton',custom:1}],right:[{id:'other'}]};
  for(const section of ['left','center','right'])
    rejected(addLayoutEntry(layout,section,'singleton',{allowMultiple:false}),layout);
  rejected(addLayoutEntry(layout,'left','other',{allowMultiple:false}),layout);
  assert.deepEqual(addLayoutEntry(layout,'center','singleton',{allowMultiple:true}).layout.center,
    [{id:'singleton',custom:1},{id:'singleton'}]);
  assert.deepEqual(addLayoutEntry(layout,'right','alias.singleton',{allowMultiple:false}).layout.right,
    [{id:'other'},{id:'alias.singleton'}]);
  assert.deepEqual(addLayoutEntry(layout,'left','new').layout.left,['singleton',{id:'new'}]);
});
test('remove and replacement affect only selected entry; strings become configured objects',()=>{
  const original=editorLayout();
  assert.deepEqual(removeLayoutEntry(original,'left',0).layout,
    {...original,left:[original.left[1]]});
  const replacement=replaceEntrySettings(original,'right',0,{custom:{format:'new'}});
  assert.equal(replacement.error,'');
  assert.deepEqual(replacement.layout.right,[{id:'omarchy.power',custom:{format:'new'}}]);
  assert.deepEqual(replacement.layout.left,original.left);
  assert.deepEqual(replaceEntrySettings(original,'center',0,{format:'HH:mm'}).layout.center,
    [{id:'omarchy.clock',format:'HH:mm'}]);
  for(const settings of [null,[],false,'{}',{id:'different'},Object.create({format:'inherited'})])
    rejected(replaceEntrySettings(original,'center',0,settings),original);
  assert.deepEqual(original,editorLayout());
});
test('every successful operation deep clones untouched inline and layout data',()=>{
  const original=editorLayout();
  const draft={nested:{items:[{value:4}]}};
  const results=[
    moveLayoutEntry(original,'center',0,'right',1),
    addLayoutEntry(original,'center','new',{}),
    removeLayoutEntry(original,'center',0),
    replaceEntrySettings(original,'center',0,draft)
  ];
  for(const result of results) {
    assert.equal(result.error,'');
    result.layout.left[1].nested.items[0].enabled=false;
    result.layout.vendor.untouched.push('changed');
    assert.deepEqual(original,editorLayout());
  }
  results[3].layout.center[0].nested.items[0].value=9;
  assert.deepEqual(draft,{nested:{items:[{value:4}]}});
});
test('prototype-looking own data survives clones and settings extraction without prototype mutation',()=>{
  const layout=JSON.parse('{"left":[{"id":"__proto__","__proto__":{"nested":[1]},"constructor":{"value":2}}],"center":[],"right":[],"__proto__":{"global":[3]}}');
  const draft=JSON.parse('{"__proto__":{"nested":[4]},"constructor":{"value":5},"toString":"literal"}');
  const results=[
    moveLayoutEntry(layout,'left',0,'right',0),
    addLayoutEntry(layout,'center','constructor',{}),
    removeLayoutEntry(layout,'left',0),
    replaceEntrySettings(layout,'left',0,draft)
  ];
  for(const result of results) {
    assert.equal(result.error,'');
    assert.equal(Object.getPrototypeOf(result.layout),Object.prototype);
    assert.equal(Object.hasOwn(result.layout,'__proto__'),true);
    assert.deepEqual(result.layout.__proto__,{global:[3]});
    result.layout.__proto__.global.push(9);
    assert.deepEqual(layout.__proto__,{global:[3]});
  }
  const extracted=entrySettings(layout.left[0]);
  assert.equal(Object.getPrototypeOf(extracted),Object.prototype);
  assert.equal(Object.hasOwn(extracted,'__proto__'),true);
  assert.deepEqual(extracted,JSON.parse('{"__proto__":{"nested":[1]},"constructor":{"value":2}}'));
  const inherited=Object.create({ignored:true});
  inherited.id='a';
  inherited.own=1;
  assert.deepEqual(entrySettings(inherited),{own:1});
  const replaced=results[3].layout.left[0];
  assert.equal(replaced.id,'__proto__');
  assert.equal(Object.getPrototypeOf(replaced),Object.prototype);
  assert.equal(Object.hasOwn(replaced,'__proto__'),true);
  assert.deepEqual(replaced.__proto__,{nested:[4]});
  replaced.__proto__.nested.push(8);
  assert.deepEqual(draft.__proto__,{nested:[4]});
  rejected(addLayoutEntry(layout,'right','__proto__',{allowMultiple:false}),layout);
  rejected(replaceEntrySettings(layout,'left',0,JSON.parse('{"id":null}')),layout);
});
