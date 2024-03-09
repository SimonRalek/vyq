var runBtn = document.getElementById('runCodeBtn');
var outputElt = document.getElementById('codeOutput');

const encoder = new TextEncoder();
const decoder = new TextDecoder();

const importObject = {
  env: {
    writeOut: (ptr, len) => {
      outputElt.innerText += decoder.decode(
        new Uint8Array(wasm.memory.buffer.slice(ptr, ptr + len))
      );
      outputElt.scrollTop = outputElt.scrollHeight;
    },
    now: () => Date.now(),
  },
};

fetch('../lib.wasm')
  .then((response) => response.arrayBuffer())
  .then((bytes) => WebAssembly.instantiate(bytes, importObject))
  .then((result) => {
    wasm = result.instance.exports;
    main(wasm);
  });

function main(wasm) {
  var input = document.getElementById('codeInput');
  var vm = wasm.createVM();

  function interpretString(str) {
    var slice = allocateString(wasm, str);
    wasm.interpret(vm, slice.ptr, slice.len);
    wasm.dealloc(slice.ptr, slice.len);
  }

  input.focus();
  var editor = CodeMirror(input, {
    lineNumbers: true,
    mode: "javascript",
    theme: "default",
    viewportMargin: Infinity,
  });

  document.getElementById('runCodeBtn').addEventListener('click', function () {
    var value = editor.getValue();
    // outputElt.innerText += ['\n'].join();
    outputElt.scrollTop = outputElt.scrollHeight;

    if (value === '') return;

    interpretString(value);
  });

  document.getElementById('runCodeBtnMobile').addEventListener('click', function () {
    var value = editor.getValue();
    // outputElt.innerText += ['\n'].join();
    outputElt.scrollTop = outputElt.scrollHeight;

    if (value === '') return;

    interpretString(value);
  });
}

function allocateString(wasm, str) {
  const sourceArray = encoder.encode(str);

  const len = sourceArray.length;

  const ptr = wasm.alloc(len);
  if (ptr === 0) throw 'Cannot allocate memory';

  var memoryu8 = new Uint8Array(wasm.memory.buffer);
  for (let i = 0; i < len; ++i) {
    memoryu8[ptr + i] = sourceArray[i];
  }

  return { ptr, len };
}