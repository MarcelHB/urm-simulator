class GotoProgram
  ASCII_DIGITS = (48..57).to_a
  ASSIGNMENT = ":="
  COMMENT = "#"
  EQUAL = "="
  IF = "IF"
  LABEL = ":"
  OPERATIONS = %w(+ -)
  REGISTER_MARKER = "R"
  SKIPPABLE_CHARS = ["\r","\n","\t", " "]
  SEPARATION = ";"

  attr_reader :errors, :registers, :instructions

  def initialize(io, registers = [])
    self.io = io
    self.registers = registers
    self.label_mapping = {}
    self.unresolvables = []
    self.errors = []
    self.instructions = []
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
    resolve!
    
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

    @current_label = number
    
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

    next_char!
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
    
    unless assignment == ASSIGNMENT
      errors << "[parser] #{current_line}: expecting assignment"
      return false
    end

    next_char!
    unless @current_char == REGISTER_MARKER
      errors << "[parser] #{current_line}: expecting a source register"
      return false
    end
    
    next_char!
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

    next_char!
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
    if next_label == @current_label
      errors << "[compiler] #{current_line}: a label must not jump to itself"
      return false
    end

    compile_operation!(destination_register, source_register, operation, constant, next_label)
    true
  end

  #----------------------------------------------------------------------------
  def parse_condition!
    if_token = ""
    2.times do
      if_token << @current_char
      next_char!
    end

    unless if_token == IF
      revert!(if_token)
      return false
    end

    unless @current_char == REGISTER_MARKER
      errors << "[parser] #{current_line}: expecting a register on the left"
      return false
    end

    next_char!
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

    next_char!
    compare_value = parse_number
    unless compare_value
      errors << "[parser] #{current_line}: you can only use a constant for comparison"
      return false
    end

    next_char!
    if @current_char == LABEL
      next_char!
    end

    true_jump = parse_number
    unless true_jump
      errors << "[parser] #{current_line}: expecting a destination label for true-case"
      return false
    end

    next_char!
    if @current_char == SEPARATION
      next_char!
    end

    false_jump = parse_number
    unless false_jump
      errors << "[parser] #{current_line}: expecting a destination label for false-case"
      return false
    end

    if [true_jump, false_jump].include?(@current_label)
      errors << "[compiler] #{current_line}: a label must not jump to itself"
    end

    compile_condition!(cmp_register, compare_value, true_jump, false_jump)
    true
  end

  #----------------------------------------------------------------------------
  def compile_condition!(register, constant, true_jump, false_jump)
    if constant != 0
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

      if label_mapping.has_key?(true_jump)
        target = label_mapping[true_jump] - (instructions.length - 2)
        self.instructions[-1][:arg] = [register, -target]
      else
        unresolvables << { :type => :jz, :instruction => instructions.length - 2, :label => true_jump }
      end
      if label_mapping.has_key?(false_jump)
        target = label_mapping[false_jump] - (instructions.length - 1)
        self.instructions[-2][:arg] = [-target]
      else
        unresolvables << { :type => :jmp, :instruction => instructions.length - 3, :label => false_jump }
      end
    else
      # if comparing against 0, just use a jz
      self.instructions += [
        { :op => :jz, :arg => [register, nil] },
        { :op => :jmp, :arg => [nil] }
      ]

      if label_mapping.has_key?(true_jump)
        target = label_mapping[true_jump] - (instructions.length - 2)
        self.instructions[-2][:arg] = [register, -target]
      else
        unresolvables << { :type => :jz, :instruction => instructions.length - 2, :label => true_jump }
      end
      if label_mapping.has_key?(false_jump)
        target = label_mapping[false_jump] - (instructions.length - 1)
        self.instructions[-1][:arg] = [target]
      else
        unresolvables << { :type => :jmp, :instruction => instructions.length - 1, :label => false_jump }
      end
    end
  end

  #----------------------------------------------------------------------------
  def compile_operation!(dest, src, operation, constant, next_label)
    if dest != src
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
    end

    constant.times do
      instructions << { :op => operation, :arg => [dest] }
    end

    if next_label - @current_label != 1
      if label_mapping.has_key?(next_label)
        target = instructions.length - label_mapping[next_label]
        instructions << { :op => :jmp, :arg => [-target] }
      else
        unresolvables << { :type => :jmp, :instruction => instructions.length, :label => next_label }
        instructions << { :op => :jmp, :arg => [nil] }
      end
    end
  end

  #----------------------------------------------------------------------------
  def resolve!
    resolve_jumps!
    resolve_registers!
  end

  #----------------------------------------------------------------------------
  def resolve_jumps!
    unresolvables.select{ |u| [:jmp, :jz].include?(u[:type]) }.each do |un|
      if label_mapping.has_key?(un[:label])
        target = un[:instruction] - label_mapping[un[:label]]

        if un[:type] == :jmp
          instructions[un[:instruction]][:arg] = [-target]
        else
          instructions[un[:instruction]][:arg][1] = -target
        end
      else
        # invalid labels will terminate the program
        target = un[:instruction] - (instructions.length - 1)

        if un[:type] == :jmp
          instructions[un[:instruction]][:arg] = [-target]
        else
          instructions[un[:instruction]][:arg][1] = -target
        end
      end
    end
  end

  #----------------------------------------------------------------------------
  def resolve_registers!
    max_register = 0
    instructions.each do |instr|
      if [:dec, :inc, :jz].include?(instr[:op]) && instr[:arg][0]
        max_register = [max_register, instr[:arg][0]].max
      end
    end
    max_register += 1

    unresolvables.select{ |u| u[:type] == :reg }.each do |un|
      # all this nil-appearances generated by condition
      locations = [1, un[:value] + 10, un[:value] + 11, un[:value] + 14, un[:value] + 18, un[:value] + 19]
      locations.each do |n|
        instructions[un[:instruction] + n][:arg][0] = max_register
      end
    end
  end
end
