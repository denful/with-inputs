{ outputs = inputs: import ./. { inputsOverrides = removeAttrs inputs [ "self" ]; }; }
