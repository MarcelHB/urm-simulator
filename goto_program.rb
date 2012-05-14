class GotoProgram
  ASCII_DIGITS = (48..57).to_a
  ASSIGNMENT = ":="
  COMMENT = "#"
  IF = "IF"
  LABEL = ":"
  OPERATIONS = %w(+ -)
  REGISTER_MARKER = "R"
  SKIPPABLE_CHARS = ["\r","\n","\t", " "]
  SEPARATION = ";"

  attr_reader :errors, :registers, :instructions

  def initialize(io, reigsters = [])
    self.io = op
    self.registers = registers
    self.label_mapping = {}
    self.unresolved_jumps = []
    self.current_line = 0
    parse!
  end

  #----------------------------------------------------------------------------
  def parse!
    if errors.length > 0
      return false
    end
    
    if instructions.length > 0
      return true
    end
    
    while next_line!
      self.current_line += 1
    end
    
    instructions << { :op => :halt }
    
    true
  end

  protected

  attr_accessor :string, :io, :label_mapping, :unresolvables, :current_line
  attr_writer :errors, :registers, :instructions

  #----------------------------------------------------------------------------
  def next!(n=1)
    n.times do
      @current_char = @io.getc
    end
  end

  #----------------------------------------------------------------------------
  def next_char!
    next!
    while !@io.eof? && SKIPPABLE_CHARS.include?(@current_char)
      next!
    end
  end
  
  #----------------------------------------------------------------------------
  def revert!(string)
    string.reverse.split.each do |c|
      @io.pos -= 1
      @current_char = c
    end
  end

  #----------------------------------------------------------------------------
  def next_line!
    unless @io.eof?
      next_char!
      if @current_char == COMMENT
        skip_line!
        return true
      end
      
      return parse_instruction!
    end
  end

  #----------------------------------------------------------------------------
  def skip_line!
    until @current_char == "\n"
      next!
    end
  end

  #----------------------------------------------------------------------------
  def parse_instruction!
    number = parse_number
    
    unless number
      return false
    end
    
    if label_mapping.has_key?(number)
      errors << "[parsing] #{current_line}: duplicate of label #{number}"
      return false
    end
    
    label_mapping[number] = @instructions.length
    
    next_char!
    if @current_char == LABEL
      next_char!
    end
    
    unless parse_modification!
      return parse_condition!
    end
    
    true
  end

  #----------------------------------------------------------------------------
  def parse_number
    digit_buffer = ""

    while @current_char && ASCII_DIGITS.include?(@current_char.ord)
      digit_buffer += @current_char
      next!
    end

    if digit_buffer.length > 0
      revert!(digit_buffer.split.last)
      digit_buffer.to_i
    else
      nil
    end
  end

  #----------------------------------------------------------------------------
  def parse_modification!
    unless @current_char == REGISTER_MARKER
      return false
    end

    destination_register = parse_number
    unless destination_register
      errors << "[parser] #{current_line}: expecting a destination register number"
      return false
    end

    assignment = ""
    2.times do
      next_char!
      assignment << @current_char
    end
    
    unless assign_op == ASSIGNMENT
      errors << "[parser] #{current_line}: expecting assignment"
      return false
    end

    next_char!
    unless @current_char == REGISTER_MARKER
      errors << "[parser] #{current_line}: expecting a source register"
      return false
    end

    source_register = parse_number
    unless source_register
      errors << "[parser] #{current_line}: expecting a source register number"
      return false
    end

    next_char!
    unless OPERATIONS.include?(@current_char)
      errors << "[parser] #{current_line}: expecting a +/- operation"
      return false
    end

    operation = :inc
    # '-'
    if @current_char == OPERATIONS[1] 
      operation = :dec
    end

    constant = parse_number
    unless constant
      errors << "[parser] #{current_line}: expecting a constant after +/-"
      return false
    end

    next_char!
    if @current_char == SEPARATION
      next_char!
    end

    next_label = parse_number
    unless next_label
      errors << "[parser] #{current_line}: expecting a jump destination"
      return false
    end

    compile_operation!(destination_register, source_register, operation, constant, next_label)
    true
  end

  #----------------------------------------------------------------------------
  def parse_condition!
    if_token = ""
    2.times do
      next_char!
      if << @current_char
    end

    unless if_token == IF
      revert!(if_token)
      return false
    end

    next_char!
    unless @current_char == REGISTER_MARKER
      errors << "[parser] #{current_line}: expecting a register on the left"
      return false
    end

    cmp_register = parse_number
    unless cmp_register
      errors << "[parser] #{current_line}: expecting a register number"
      return false
    end

    next_char!
    unless @current_char == EQUAL
      errors << "[parser] #{current_line}: you can only use an equivalence check"
      return false
    end

    compare_value = parse_number
    unless compare_value
      errors << "[parser] #{current_line}: you can only use a constant for comparison"
      return false
    end

    next_char!
    if @current_char == SEPARATION
      next_char!
    end

    true_jump = parse_number
    unless true_jump
      errors << "[parser] #{current_line}: expecting a destination label for true-case"
      return false
    end

    next_char!
    if @current_char == SEPERATION
      next_char!
    end

    false_jump = parse_number
    unless false_jump
      errors << "[parser] #{current_line}: expecting a destination label for false-case"
      return false
    end

    compile_condition!(cmp_register, compare_value, true_jump, false_jump)
  end

  #----------------------------------------------------------------------------
  def compile_condition!(register, constant, true_jump, false_jump)
    unresolvables << { :type => :reg, :instruction => instructions.length, :value => constant }
    # copy register to comparable
    self.instructions += [
      { :op => :jz, :arg => [register, 5] }, # copy register to <unknown yet>
      { :op => :inc, :arg => [nil] },
      { :op => :inc, :arg => [0] },
      { :op => :dec, :arg => [register] },
      { :op => :jmp, :arg => [-4] },
      { :op => :jz, :arg => [0, 4] },       # reset register
      { :op => :inc, :arg => [register] },
      { :op => :dec, :arg => [0] },
      { :op => :jmp, :arg => [-3] }
    ]

    # load constant to 0
    constant.times do 
      instructions << { :op => :inc, :arg => [0] }
    end

    # comparison
    self.instructions += [
      { :op => :jz, :arg => [0, 5] },     # constant 0?
      { :op => :jz, :arg => [nil, 5] },   # aux reg 0, but constant > 0
      { :op => :dec, :arg => [nil] },
      { :op => :dec, :arg => [0] },
      { :op => :jmp, :arg => [-4] },
      { :op => :jz, :arg => [nil, 5] },   # aux reg 0, too?
      { :op => :jz, :arg => [0, 3] },     # clear 0
      { :op => :dec, :arg => [0] },
      { :op => :jmp, :arg => [-2] },
      { :op => :jmp, :arg => [nil] },     # jump if false
      { :op => :jmp, :arg => [nil] },     # jump if true
    ]

    # TODO: handle jump targets!
  end

  #----------------------------------------------------------------------------
  def compile_operation!(dest, src, operation, constant, next_label)
    # copy src to dest
    self.instructions += [
      { :op => :jz, :arg => [dest, 3] }, # clear dest
      { :op => :dec, :arg => [dest] },
      { :op => :jmp, :arg => [-2] },
      { :op => :jz, :arg => [src, 5] }, # set dest = src
      { :op => :inc, :arg => [dest] },
      { :op => :inc, :arg => [0] },
      { :op => :dec, :arg => [src] },
      { :op => :jmp, :arg => [-4] },
      { :op => :jz, :arg => [0, 4] }, # reset src
      { :op => :inc, :arg => [src] },
      { :op => :dec, :arg => [0] },
      { :op => :jmp, :arg => [-3] }
    ]

    constant.times do
      instructions << { :op => :operation, :arg => [dest] }
    end

    if label_mapping.has_key?(next_label)
      target = instructions.length - label_mapping[next_label]
      instructions << { :op => :jmp, :arg => [target] }
    else
      unresolvables << { :type => :jump, :instruction => intructions.length, :label => next_label }
      instructions << { :op => :jmp, :arg => [1] }
    end
  end
end
