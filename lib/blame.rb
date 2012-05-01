class Blame
  attr_accessor :author, :exceptions

  def initialize(name)
    self.author = name
    self.exceptions = []
  end

  def sort_exceptions!
    self.exceptions.sort!{|a, b| b.score <=> a.score}
  end

  def score
    unless @score
      @score =  # number of exceptions
                #self.exceptions.length * 
                # sum number of counts over all exceptions, then log
                self.exceptions.map(&:score).reduce(:+)
    end
    
    @score
  end
end
