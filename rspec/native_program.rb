class NativeProgram
  attr_accessor :instructions, :errors, :registers
  
  def initialize(instructions, errors, registers)
    self.instructions = instructions
    self.errors = errors
    self.registers = registers
  end
end