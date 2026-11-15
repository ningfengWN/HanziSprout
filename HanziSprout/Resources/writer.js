'use strict';
let writer, character, data, cursor = 0, generation = 0, paused = false, busy = false, outline = true;
const $ = id => document.getElementById(id);
function status(text) { $('status').textContent = text; }
function size() { return Math.max(80, Math.floor(Math.min($('stage').clientWidth, $('stage').clientHeight))); }
function setBusy(value) { busy = value; $('step').disabled = value; }
function reset() {
  generation++; paused = false; cursor = 0;
  $('pause').textContent = '暂停'; setBusy(false);
  if (writer) { writer.cancelQuiz(); writer.hideCharacter({duration:0}); }
}
function build() {
  const side = size(); $('square').style.width = side + 'px'; $('square').style.height = side + 'px';
  if (writer) writer.hideCharacter({duration:0});
  $('target').replaceChildren();
  writer = HanziWriter.create('target', character, {
    width:side, height:side, padding:side * 0.065,
    showCharacter:false, showOutline:outline,
    strokeColor:'#245f49', outlineColor:'#e6e9df',
    strokeAnimationSpeed:Number($('speed').value), delayBetweenStrokes:350,
    charDataLoader:(_, complete) => complete(data)
  });
}
async function play() {
  reset(); const token = generation; setBusy(true);
  status('看清起笔，跟着慢慢写');
  const result = await writer.animateCharacter({onComplete:() => { if(token === generation) status(`写好了 · 共 ${data.strokes.length} 笔`); }});
  if(token !== generation || (result && result.canceled)) return;
  cursor = data.strokes.length; paused = false; $('pause').textContent = '暂停'; setBusy(false);
}
window.start = function(char, strokeData) {
  character = char; data = strokeData;
  if (!data || !data.strokes || !data.strokes.length) {
    const side = size(); $('square').style.width = side+'px'; $('square').style.height = side+'px';
    $('fallback').textContent = char; $('fallback').style.display = 'block';
    status('这个字暂时没有笔顺数据，请向老师或家长确认写法。');
    document.querySelectorAll('button,input').forEach(x => x.disabled = true); return;
  }
  build(); play();
};
$('play').onclick = () => play();
$('pause').onclick = () => {
  if(!busy) return;
  paused = !paused;
  if(paused) writer.pauseAnimation(); else writer.resumeAnimation();
  $('pause').textContent = paused ? '继续' : '暂停';
};
$('step').onclick = async () => {
  if(busy) return;
  if(cursor >= data.strokes.length) reset();
  const token = generation; setBusy(true);
  await writer.animateStroke(cursor);
  if(token !== generation) return;
  cursor++; status(`第 ${cursor} 笔 / 共 ${data.strokes.length} 笔`); setBusy(false);
};
$('outline').onclick = () => {
  outline = !outline;
  if(outline) writer.showOutline(); else writer.hideOutline();
  $('outline').textContent = outline ? '隐藏底字' : '显示底字';
};
$('speed').onchange = () => { reset(); build(); play(); };
let timer;
new ResizeObserver(() => { clearTimeout(timer); timer = setTimeout(() => { if(data) { reset(); build(); play(); } }, 150); }).observe($('stage'));
document.addEventListener('visibilitychange', () => {
  if(document.hidden && writer && busy && !paused) { paused = true; writer.pauseAnimation(); $('pause').textContent = '继续'; }
});
