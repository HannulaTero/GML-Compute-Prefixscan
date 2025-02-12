/// @desc DEFINE HELPER METHODS.


// For logging messages and such.
Log = function(_message)
{
  show_debug_message(_message);
  array_push(log, _message);
  if (array_length(log) > 24)
  {
    array_shift(log);
  }
};


// For randomizing input.
Randomize = function()
{
  // Randomize all items.
  Log("Randomizing input...");
  var _buff = buffer.input;
  var _min = inputRange[0];
  var _max = inputRange[1];
  buffer_seek(_buff, buffer_seek_start, 0);
  repeat(itemCount)
  {
    buffer_write(_buff, buffer_f32, random_range(_min, _max));
  }
  Log("Randomized input!");
  
  // Clear the output.
  Log("Clearing output...");
  buffer_fill(buffer.output, 0, buffer_f32, 0, buffer.bytes);
  Log("Cleared output!");
  Slice();
};


// For getting slices of inputs and outputs.
Slice = function()
{
  Log("Reading input/output slices...");
  var _dtype = buffer_f32;
  var _dsize = buffer_sizeof(_dtype);
  var _count = min(itemCount, slice.count);
  array_resize(slice.index, _count);
  array_resize(slice.input, _count);
  array_resize(slice.output, _count);
  for(var i = 0; i < _count; i++)
  {
    var _index = floor(itemCount * i / _count);
    var _offset = _index * _dsize;
    slice.index[i] = string_format(_index, 0, 0);
    slice.input[i] = string_format(buffer_peek(buffer.input, _offset, _dtype), 0, 2);
    slice.output[i] = string_format(buffer_peek(buffer.output, _offset, _dtype), 0, 2);
  }
  array_insert(slice.index, 0, "Indexes");
  array_insert(slice.input, 0, "Inputs");
  array_insert(slice.output, 0, "Outputs");
  Log("Done reading input/output slices!");
  Log("");
};


TimerBegin = function(_message="")
{
  var _timer = { 
    time: get_timer(), 
    message: _message 
  };
  array_push(timers, _timer);
  return _timer;
};


TimerEnd = function()
{
  var _timer = array_pop(timers);
  var _time = (get_timer() - _timer.time) / 1000.0;
  var _length = string_length(_timer.message);
  var _timeStr = string_format(_time, 32 - _length, 2);
  Log($"    {_timer.message}{_timeStr} ms");
};



