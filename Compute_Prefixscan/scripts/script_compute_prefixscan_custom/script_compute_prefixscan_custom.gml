/*
  
  
  PARAMETERS
    
    device : GPUDevice
      If in future you can request own devices.
    
    dtype : string
      Defines datatype, which is used for scan. 
      If you use custom datatype, use import for the struct etc.
      
    dsize : real
      If you use custom datatype, provide how many bytes it requires.
      This will be used to caclulate count of items, if it is not separately provided.
    
    import : array<string>
      Sources, which are appended to top of the shader.
      This can be used to provide datatype or functions for the scan.
      
    operation : string
      Operation which scan will use on each pass.
      Assumes expression if there is no "return".
      Either use "lhs" and "rhs" as operand names, or provide as parameters.
      
    lhs : string
      Explicit left-hand-side operator name.
      
    rhs : string
      Explicit left-hand-side operator name.
    
    workgroupSize : real
      Define how
   
   
  EXAMPLES
    
    // Creates Prefix-sum scan for "f32".
    computeSumF32 = new Prefixscan(); 
    
    // Creates Prefix-sum scan for "u32"
    computeSumU32 = new Prefixscan({ dtype: "u32" }); 
    
    // Creates scan, which calculates product instead of sum.
    computeProdVec4u = new Prefixscan({ 
      dtype: "vec4u", 
      dsize: 4 * 4, 
      operation: "lhs * rhs" 
    }); 
    
*/
/// @func Prefixscan(_params);
/// @desc Prefix-scan with custom pipeline, utilizes compute shaders. 
/// @param {Struct} _params 
function Prefixscan(_params) constructor
{
  /// @func Dispatch(_dst, _src, _offset, _count);
  /// @desc Output count needs to be power of 2.
  /// @param {Struct.ComputeBuffer} _dst  
  /// @param {Struct.ComputeBuffer} _src  
  /// @param {Real} _offset Offset in item indexes.
  /// @param {Real} _count Count of items
  static Dispatch = function(_dst, _src, _offset=0, _count=ceil(_src.size / self.dsize))
  {
    // Preparations.
    var _alignment = 256; // Dynamic offsets require aligment of 256.
    var _workgroupCounts = array_create(64);
    var _passCount = 0;
    
    
    // Define up-sweep pass parameters.
    var _buffer = buffer_create(16_384, buffer_fixed, 1);
    for(var i = 1.0; i < _count; i *= 2.0)
    {
      // Align the values.
      buffer_seek(_buffer, buffer_seek_start, _passCount * _alignment);
      
      // Define uniforms.
      var _invocationJump = i * 2;
      var _invocationLook = i;
      var _invocationCount = ceil(_count / _invocationJump);
      var _invocationOffset = (i - 1);
      buffer_write(_buffer, buffer_u32, _invocationJump);
      buffer_write(_buffer, buffer_u32, _invocationLook);
      buffer_write(_buffer, buffer_u32, _invocationCount);
      buffer_write(_buffer, buffer_u32, _invocationOffset + _offset);
      _workgroupCounts[_passCount] = ceil(_invocationCount / self.workgroupSize);
      _passCount++;
    }
    show_debug_message(_passCount);
    
    
    // Define down-sweep pass parameters.
    for(var i = floor(_count * 0.5); i > 1.0; i *= 0.5)
    {
      // Align the values.
      buffer_seek(_buffer, buffer_seek_start, _passCount * _alignment);
      
      // Define uniforms.
      var _invocationJump = i;
      var _invocationLook = i * 0.5;
      var _invocationCount = floor(_count / i) - 1;
      var _invocationOffset = (i - 1);
      buffer_write(_buffer, buffer_u32, _invocationJump);
      buffer_write(_buffer, buffer_u32, _invocationLook);
      buffer_write(_buffer, buffer_u32, _invocationCount);
      buffer_write(_buffer, buffer_u32, _invocationOffset + _offset);
      _workgroupCounts[_passCount] = ceil(_invocationCount / self.workgroupSize);
      _passCount++;
    }
    show_debug_message(_passCount);
    
    
    // Create uniform containing pass-information.
    // The uniform contains information for all passes.
    // This way it is only needed to move once, and then just change dynamic offset.
    var _uni = device.createBuffer({
      label: "Prefixscan Uniform",
      size: _passCount * _alignment, 
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    device.queue.writeBuffer(_uni, 0, _buffer, 0, _uni.size);
    
    
    // Create bindgroups for the dispatch.
    var _bindGroup = device.createBindGroup({
      label: "Prefix-scan Bindgroup",
      layout: self.bindGroupLayout,
      entries: [
        { binding: 0, resource: { buffer: _uni, size: 4 * 4 } },
        { binding: 1, resource: { buffer: _dst } },
      ]
    });
    
    
    // Copy contents of input into the target.
    var _encoder = device.createCommandEncoder();
    _encoder.copyBufferToBuffer(_src, 0, _dst, 0, _count * self.dsize);
    
    // Begin the compute pass.
    var _pass = _encoder.beginComputePass();
    _pass.setPipeline(self.pipelineCompute);
    
    // Do the compute passes.
    for(var i = 0; i < _passCount; i++)
    {
      _pass.setBindGroup(0, _bindGroup, [ i * _alignment ]);
      _pass.dispatchWorkgroups(_workgroupCounts[i]);
    }
    _pass.end_();
    
    // Finalize the buffer.
    var _commandBuffer = _encoder.finish();
    device.queue.submit([_commandBuffer]);
    
    
    // Finalization.
    _uni.destroy();
    array_resize(_workgroupCounts, 0);
    return self;
  };
  
  
  
  /// @func Destroy();
  /// @desc 
  static Destroy = function()
  {
    return self;
  };
  
  
  
  // Define what data the buffer contains.
  self.device = _params[$ "device"] ?? GPU.requestAdapter().requestDevice();
  self.dtype = _params[$ "dtype"] ?? "f32";
  self.dsize = _params[$ "dsize"] ?? 4;
  self.workgroupSize = _params[$ "workgroupSize"] ?? 256;
  
  
  // If something is required for the function or datatype.
  var _imports = string_join_ext("\n", _params[$ "import"] ?? []);
    
  // Define operation. Allow implicit return.
  var _lhs = _params[$ "lhs"] ?? "lhs"; // If you want other operand names.
  var _rhs = _params[$ "rhs"] ?? "rhs"; // 
  var _operation = _params[$ "operation"] ?? $"{_lhs} + {_rhs}";
  if (string_pos("return", _operation) == 0)
  {
    _operation = $"return {_operation};";
  }
  
    
  // Create the shader modules.
  self.shaderModule = device.createShaderModule({ 
    label: "Prefix-scan Shader Module",
    code: Prefixscan.Replace({
        IMPORTS : _imports,
        WORKGROUP_SIZE: string(workgroupSize),
        DATATYPE : self.dtype,
        OPERATION : _operation,
        LHS : _lhs, 
        RHS : _rhs,
      }, Prefixscan.shaderSource
    )
  });
  
  
  // Create bindgroup layouts.
  self.bindGroupLayout = device.createBindGroupLayout({
    label: "Prefix-scan BindGroup Layout",
    entries: [{
      binding: 0, 
      visibility: GPUShaderStage.COMPUTE,
      buffer: { type : "uniform", minBindingSize: 4 * 4 , hasDynamicOffset: true },
    }, {
      binding: 1, 
      visibility: GPUShaderStage.COMPUTE,
      buffer: { type : "storage" },
    }]
  });
  
  
  // Create pipeline layout.
  self.pipelineLayout = device.createPipelineLayout({
    label: "Prefix-scan Pipeline Layout",
    bindGroupLayouts: [ self.bindGroupLayout ]
  });
  
  
  // Create compute pipeline.
  self.pipelineCompute = device.createComputePipeline({
    label: "Prefix-scan Pipeline",
    layout: self.pipelineLayout,
    compute: {
      module: self.shaderModule,
      entrypoint: "computeSweep"
    }
  });
  
  
  // Prefix-scan source.
  static shaderSource = (@'
    
    {{IMPORTS}}
    
    
    fn ScanOperation({{LHS}} : {{DATATYPE}}, {{RHS}} : {{DATATYPE}}) -> {{DATATYPE}}
    {
      {{OPERATION}}
    }
    
    
    struct ScanUniforms
    {
      jump : u32,
      look : u32,
      count : u32, 
      offset : u32,
    };
    
    
    @group(0) @binding(0) var <uniform> uni : ScanUniforms;
    @group(0) @binding(1) var <storage, read_write> buff: array<{{DATATYPE}}>;
    
    
    @compute 
    @workgroup_size({{WORKGROUP_SIZE}})
    fn computeSweep(@builtin(global_invocation_id) id : vec3u)
    {
      if (id.x >= uni.count) 
      {
        return;
      }
      
      var indexLhs : u32 = uni.offset + id.x * uni.jump;
      var indexRhs : u32 = indexLhs + uni.look;
      buff[indexRhs] = ScanOperation( 
        buff[indexLhs], 
        buff[indexRhs] 
      );
    }
  ');
  
  
  // Helper function.
  static Replace = function(_placeholders={}, _string="")
  {
    static context = { str : "" };
    static functor = method(context, function(_key, _item)
    {
      // feather ignore GM1041
      str = string_replace_all(str, "{{"+_key+"}}", _item);
    });
    context.str = _string;
    struct_foreach(_placeholders, functor);
    return context.str;
  };
}






