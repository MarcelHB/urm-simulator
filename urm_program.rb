class URMProgram
  OPERATIONS = %w(A S)
  OPERATION_ARGS = %w(R C)
  SEPERATOR = ";"
  ITERATION_BEGIN = "("
  ITERATION_END = ")"
  ASCII_DIGITS = (48..57).to_a

  attr_reader :errors, :registers, :instructions

  def initialize(io, registers = [])
    self.io = io
    self.registers = registers
    self.stack = []
    self.errors = []
    self.instructions = []
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

    self.consumed = 0
    next_char!
    while next_token!
    end

    if @io.pos > consumed && errors.length == 0
      errors << "[parsing] garbage at #{@io.pos}: #{@current_char}"
      return false
    end

    if stack.length > 0 && errors.length == 0
      errors << "[parsing] missing closing element from #{stack.last[:type]} at byte #{stack.last[:byte]}"
      return false
    end

    instructions << { :op => :halt }

    true
  end

  protected

  attr_accessor :string, :stack, :io, :consumed
  attr_writer :errors, :registers, :instructions

  #----------------------------------------------------------------------------
  def next!(n = 1)
    n.times do
      @current_char = @io.getc
    end
  end

  #----------------------------------------------------------------------------
  def accept!
    self.consumed = @io.pos
    next_char!
  end

  #----------------------------------------------------------------------------
  def next_token!
    success = false
    if @stack.empty?
      success = parse_operations!
    else
      top = @stack.last

      if top[:type] == :iteration
        success = parse_operations!
        unless success
          success = parse_iteration_end!
        end
      end
    end

    if @io.eof? 
      false
    else
      success
    end
  end

  #----------------------------------------------------------------------------
  def parse_operations!
    if @current_char != SEPERATOR
      unless parse_iteration!
        unless parse_operation!
          return parse_operation_with_args!
        end
      end
    else
      accept!
    end
    true
  end

  #----------------------------------------------------------------------------
  def next_char!
    next!
    while !@io.eof? && @current_char == ' '
      next!
    end
  end

  #----------------------------------------------------------------------------
  def parse_operation!
    instruction = nil

    case @current_char
    when OPERATIONS[0] # 'A'
      instruction = :inc
    when OPERATIONS[1] # 'S'
      instruction = :dec
    else
      return false
    end

    next!
    number = parse_number

    if number
      @instructions << { :op => instruction, :arg => [number] }
      accept!
      true
    else
      errors << "[parsing] expected a number at #{io.pos}"
      false
    end
  end

  #----------------------------------------------------------------------------
  def parse_iteration!
    if @current_char == ITERATION_BEGIN
      @instructions << { :op => :jz, :arg => [] }
      @stack.push({ :type => :iteration, :instruction => @instructions.length - 1, :byte => @io.pos })
      accept!

      true
    else
      false
    end
  end

  #----------------------------------------------------------------------------
  def parse_iteration_end!
    top = @stack.last
    if @current_char == ITERATION_END && top[:type] == :iteration
      top = @stack.pop
      distance = @instructions.length - top[:instruction]
      @instructions << { :op => :jmp, :arg => [-distance] }

      next_char!
      register = parse_number

      unless register
        errors << "[parsing] required operation register at #{@io.pos}"
        return false
      end

      @instructions[top[:instruction]][:arg] = [register, distance + 1]
      accept!

      true
    else
      false
    end
  end

  #----------------------------------------------------------------------------
  def parse_operation_with_args!
    instruction = :move

    case @current_char
    when OPERATION_ARGS[0] # 'R'
      instruction = :move
    when OPERATION_ARGS[1] # 'C'
      instruction = :chg
    else
      return false
    end

    next_char!
    if @current_char == ITERATION_BEGIN
      next_char!

      source = parse_number
      unless source
        errors << "[parsing] required source register at #{@io.pos}"
        return false
      end

      destinations = []
      next_char!

      if @current_char == ITERATION_END
        return true
      elsif @current_char == SEPERATOR
        next_char!
        destinations = parse_destination_list
        if @current_char == ITERATION_END
          accept!
        else
          errors << "[parsing] unclosed operation at #{@io.pos}"
          return false
        end
      else
        return false
      end

      if instruction == :move
        move!(source, destinations)
      else
        change!(source, destinations)
      end

      true
    else
      errors << "[parsing] expected '#{ITERATION_BEGIN}' at #{@io.pos}"
      false
    end
  end

  #----------------------------------------------------------------------------
  def parse_destination_list
    destinations = []

    while true
      number = parse_number

      if number
        destinations << number
      else
        errors << "[parsing] expected destination at #{@io.pos}"
        break
      end

      next_char!
      if @current_char == ITERATION_END
        break
      elsif @current_char == ","
        next_char!
      else
        errors << "[parsing] expected ',' or ')' at #{@io.pos}"
        break
      end
    end

    destinations
  end

  #----------------------------------------------------------------------------
  def parse_number
    digit_buffer = ""

    while ASCII_DIGITS.include?(@current_char.ord)
      digit_buffer += @current_char
      if @io.eof?
        break
      else
        next!
      end
    end

    if !@io.eof? || !ASCII_DIGITS.include?(@current_char.ord)
      @io.pos -= 1
    end

    if digit_buffer.length > 0
      @current_char = digit_buffer.split("").last
      digit_buffer.to_i
    else
      nil
    end
  end

  #----------------------------------------------------------------------------
  def move!(source, destinations)
    @instructions << { :op => :jz, :arg => [source, 1] }
    exiting_instruction = @instructions.length - 1

    destinations.each do |dest|
      @instructions << { :op => :inc, :arg => [dest] }
    end

    @instructions << { :op => :dec, :arg => [source] }
    distance = @instructions.length - exiting_instruction
    @instructions << { :op => :jmp, :arg => [-distance] }
    @instructions[exiting_instruction][:arg] = [source, distance + 1]
  end

  #----------------------------------------------------------------------------
  def change!(source, destinations)
    move!(source, [0] + destinations)
    move!(0, [source])
  end
end
