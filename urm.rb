require ".\\urm_program.rb"

class URM  
  attr_reader :registers, :errors
  
  def initialize(program)
    self.program = program
    self.registers = []
    self.idx = 0
    self.stopped = false
    self.errors = []
  end
  
  #----------------------------------------------------------------------------
  def start!
    if program.errors.empty?
      prealloc_registers!
      until @stopped
        instruction = @program.instructions[@idx]
        args = instruction[:arg]

       case instruction[:op]
        when :inc
          increase!(args[0])
        when :dec
          decrease!(args[0])
        when :jz
          if @registers[args[0]] == 0
            @idx = @idx + args[1]
            next
          end
        when :jmp
          @idx = @idx + args[0]
          next
        when :halt
          @stopped = true
        else
          errors << "Illegal instruction #{instruction[:op]} at #{@idx}"
          @stopped = true
        end
        
        @idx = @idx + 1
      end
    end
  end
  
  #----------------------------------------------------------------------------
  def self.run(program)
    u = URM.new(program)
    u.start!
    u.registers
  end
    
  private
  
  attr_accessor :idx, :stopped, :program
  attr_writer :registers, :errors
  
  #----------------------------------------------------------------------------
  def prealloc_registers!
    program.instructions.each do |instruction|
      case instruction[:op]
      when :inc
        alloc!(instruction[:arg][0])
      when :dec
        alloc!(instruction[:arg][0])
      when :jz
        alloc!(instruction[:arg][0])
      end
    end
    
    program.registers.each_index { |i| @registers[i] = program.registers[i] }
    @registers.map! { |reg| reg < 0 ? 0 : reg }
  end
  
  #----------------------------------------------------------------------------
  def alloc!(register)
    if register >= @registers.length
      @registers = Array.new(register + 1, 0)
    end
  end
  
  #----------------------------------------------------------------------------
  def increase!(register)
    @registers[register] += 1
  end
  
  #----------------------------------------------------------------------------
  def decrease!(register)
    if @registers[register] > 0
      @registers[register] -= 1
    else
      @registers[register] = 0
    end
  end
end
