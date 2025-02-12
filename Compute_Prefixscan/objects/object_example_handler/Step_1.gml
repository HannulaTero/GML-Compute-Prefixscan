/// @desc DISPATCH.


// Dispatch sequential Prefix Sum -scan.
if (keyboard_check_pressed(ord("1")))
{
  // Preparations.
  Log("Starting sequential scan...");
  var _buffInput = buffer.input;
  var _buffOutput = buffer.output;
  TimerBegin("Sequential scan");
  
  // Could be done in-place, but as now there are separate buffers, so let's use those.
  buffer_seek(_buffInput, buffer_seek_start, 0);
  buffer_seek(_buffOutput, buffer_seek_start, 0);
  var _res = buffer_read(_buffInput, buffer_f32);
  buffer_write(_buffOutput, buffer_f32, _res);
  repeat(itemCount - 1)
  {
    _res += buffer_read(_buffInput, buffer_f32);
    buffer_write(_buffOutput, buffer_f32, _res);
  }
  
  TimerEnd();
  Log("Finished sequential scan!");
  Slice();
}


// Dispatch parallel Prefix Sum -scan with Compute API.
if (keyboard_check_pressed(ord("2")))
{
  compute.Execute();
}


// Dispatch parallel Prefix Sum -scan with Custom Pipeline.
if (keyboard_check_pressed(ord("3")))
{
  custom.Execute();
}




