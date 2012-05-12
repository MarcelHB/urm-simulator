require "#{File.dirname(__FILE__)}/urm_program"

# A LOOP program is an URM program that does not allow modification of
# the counting register except a single decrementation per loop (at the end)

class LoopProgram < URMProgram
  def parse_iteration_end!
    top = @stack.last
    
    unless super
      return false
    end
    
    iteration_register = @instructions[top[:instruction]][:arg][0]
    unloopy = false
    
    i = top[:instruction]
    
    until i == @instructions.length - 1 || unloopy
      case @instructions[i][:op]
      when :inc
        if @instructions[i][:arg][0] == iteration_register
          @errors << "[parser] illegaly attempting to increase counter #{iteration_register}"
          unloopy = true
        end
      when :dec
        if @instructions[i][:arg][0] == iteration_register
          if i != @instructions.length - 2
            @errors << "[parser] illegal location of counter decrement of #{iteration_register}"
            unloopy = true
          end
        end
      end
      
      if i == @instructions.length - 2
        if @instructions[i][:op] != :dec || @instructions[i][:arg][0] != iteration_register
          @errors << "[parser] not decreasing the counter #{iteration_register}"
          unloopy = true
        end
      end
      
      i += 1
    end
    
    true
  end
end