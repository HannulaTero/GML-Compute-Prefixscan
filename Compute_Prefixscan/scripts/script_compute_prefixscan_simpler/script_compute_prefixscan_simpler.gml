/*
  
  
  PARAMETERS
    
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
    computeSumF32 = new ComputeScan(); 
    
    // Creates Prefix-sum scan for "u32"
    computeSumU32 = new ComputeScan({ dtype: "u32" }); 
    
    // Creates scan, which calculates product instead of sum.
    computeProdVec4u = new ComputeScan({ 
      dtype: "vec4u", 
      dsize: 4 * 4, 
      operation: "lhs * rhs" 
    }); 
    
*/
/// @func ComputeScan(_params);
/// @desc Prefix-scan with compute shaders, uses GML Compute API.
/// @param {Struct} _params 
function ComputeScan(_params={}) constructor
{
  // Get the workgroup size.
  self.workgroupSize = _params[$ "workgroupSize"] ?? 256;
  self.dtype = _params[$ "dtype"] ?? "f32"; // To allow other datatypes, add imports if requires struct etc.
  self.dsize = _params[$ "dsize"] ?? 4;     // If custom dataformat is used, provide datasize.
    
  // Create shader for copying the inputs over.
  // feather ignore once GM1041
  self.shaderCopy = self.Variant(ComputeScan.shaderSourceCopy, _params);
  self.shaderCopy.__addUniform({ name: "uni", type: ShaderUniformType.BUFFER, group : 0, binding : 0 });
  self.shaderCopy.__addUniform({ name: "src", type: ShaderUniformType.BUFFER, group : 0, binding : 1 });
  self.shaderCopy.__addUniform({ name: "dst", type: ShaderUniformType.BUFFER, group : 0, binding : 2 });
  
  // Create shader for up-down -sweep pass.
  // feather ignore once GM1041
  self.shaderSweep = self.Variant(ComputeScan.shaderSourceSweep, _params);
  self.shaderSweep.__addUniform({ name: "uni", type: ShaderUniformType.BUFFER, group : 0, binding : 0 });
  self.shaderSweep.__addUniform({ name: "buff", type: ShaderUniformType.BUFFER, group : 0, binding : 1 });
   
  
  /// @func Dispatch(_dst, _src, _offset, _count);
  /// @desc Output count needs to be power of 2.
  /// @param {Struct.ComputeBuffer} _dst
  /// @param {Struct.ComputeBuffer} _src
  /// @param {Real} _offset
  /// @param {Real} _count
  static Dispatch = function(_dst, _src, _offset=0, _count=(_src.size / self.dsize))
  {
    // Copy source into destination.
    ComputeScan.buffUniforms.fromIntArray([ _offset, _count, 0, 0 ]);
    self.shaderCopy.setBuffer(shaderCopy.getUniform("uni"), ComputeScan.buffUniforms);
    self.shaderCopy.setBuffer(shaderCopy.getUniform("src"), _src);
    self.shaderCopy.setBuffer(shaderCopy.getUniform("dst"), _dst);
    self.shaderCopy.dispatch(ceil(_count / self.workgroupSize));
    
    // Do up-sweep phase.
    self.shaderSweep.setBuffer(shaderSweep.getUniform("uni"), ComputeScan.buffUniforms);
    self.shaderSweep.setBuffer(shaderSweep.getUniform("buff"), _dst);
    for(var i = 1.0; i < _count; i *= 2.0)
    {
      var _invocationJump = i * 2;
      var _invocationLook = i;
      var _invocationCount = ceil(_count / _invocationJump);
      var _invocationOffset = (i - 1);
      ComputeScan.buffUniforms.fromIntArray([
        _invocationOffset + _offset,
        _invocationCount,
        _invocationJump, 
        _invocationLook
      ]);
      self.shaderSweep.dispatch(
        ceil(_invocationCount / self.workgroupSize)
      );
    }
    
    // Do down-sweep phase.
    self.shaderSweep.setBuffer(shaderSweep.getUniform("buff"), _dst);
    self.shaderSweep.setBuffer(shaderSweep.getUniform("uni"), ComputeScan.buffUniforms);
    for(var i = floor(_count * 0.5); i > 1.0; i *= 0.5)
    {
      var _invocationJump = i;
      var _invocationLook = i * 0.5;
      var _invocationCount = floor(_count / i) - 1;
      var _invocationOffset = i - 1;
      ComputeScan.buffUniforms.fromIntArray([
        _invocationOffset + _offset,
        _invocationCount,
        _invocationJump, 
        _invocationLook
      ]);
      self.shaderSweep.dispatch(
        ceil(_invocationCount / self.workgroupSize)
      );
    }
    
    // Return as result.
    return self;
  };
  
  
  static Destroy = function()
  {
    self.shaderCopy.destroy();
    self.shaderSweep.destroy();
    return self;
  };
  
  
  // For generating different variants of same shader.
  static Variant = function(_source, _params={})
  {
    // If something is required for the function or datatype.
    var _import = string_join_ext("\n", _params[$ "import"] ?? []);
    
    // Define what data the buffer contains.
    var _datatype = _params[$ "dtype"] ?? "f32";
    
    // Define operation. Allow implicit return.
    var _lhs = _params[$ "lhs"] ?? "lhs"; // If you want other operand names.
    var _rhs = _params[$ "rhs"] ?? "rhs"; // 
    var _operation = _params[$ "operation"] ?? $"{_lhs} + {_rhs}";
    if (string_pos("return", _operation) == 0)
    {
      _operation = $"return {_operation};";
    }
    
    // Apply to the source.
    _source = string_replace_all(_source, "{{IMPORTS}}", _import);
    _source = string_replace_all(_source, "{{UNIFORMS}}", ComputeScan.sourceUniforms);
    _source = string_replace_all(_source, "{{OPERATION}}", _operation);
    _source = string_replace_all(_source, "{{LHS}}", _lhs);
    _source = string_replace_all(_source, "{{RHS}}", _rhs);
    _source = string_replace_all(_source, "{{DATATYPE}}", _datatype);
    _source = string_replace_all(_source, "{{WORKGROUP_SIZE}}", string(workgroupSize));
    return new ComputeShader(_source);
  };
  
  
  static buffUniforms = new ComputeBuffer(4 * 4, false, true);
  static sourceUniforms = (@'
    struct Uniforms
    {
      offset : u32,
      count : u32, 
      jump : u32,
      look : u32,
    };
  ');
  
  
  static shaderSourceCopy = (@'
    {{IMPORTS}}
    {{UNIFORMS}}
    
    @group(0) @binding(0) var <storage, read> uni : Uniforms;
    @group(0) @binding(1) var <storage, read> src: array<{{DATATYPE}}>;
    @group(0) @binding(2) var <storage, read_write> dst: array<{{DATATYPE}}>;
      
    @compute @workgroup_size({{WORKGROUP_SIZE}})
    fn main(@builtin(global_invocation_id) id : vec3u)
    {
      if (id.x >= uni.count) 
      {
        return;
      }
      var indexA = uni.offset + id.x;
      dst[indexA] = src[indexA];
    }
  ');
  
  
  static shaderSourceSweep = (@'
    {{IMPORTS}}
    {{UNIFORMS}}
    
    fn ScanOperation({{LHS}} : {{DATATYPE}}, {{RHS}} : {{DATATYPE}}) -> {{DATATYPE}}
    {
      {{OPERATION}}
    }
    
    @group(0) @binding(0) var <storage, read> uni : Uniforms;
    @group(0) @binding(1) var <storage, read_write> buff: array<{{DATATYPE}}>;
      
    @compute @workgroup_size({{WORKGROUP_SIZE}})
    fn main(@builtin(global_invocation_id) id : vec3u)
    {
      if (id.x >= uni.count) 
      {
        return;
      }
      var indexLhs : u32 = uni.offset + id.x * uni.jump;
      var indexRhs : u32 = indexLhs + uni.look;
      buff[indexRhs] = ScanOperation( buff[indexLhs], buff[indexRhs] );
    }
  ');
}

