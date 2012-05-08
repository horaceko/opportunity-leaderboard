class ExceptionGroup
  attr_accessor :error_class, :error_message, :notices_count, :backtrace, :most_recent_notice, :file, :line, :created_at, :id

  def initialize(options = {})
    self.error_class = options[:error_class]
    self.error_message = options[:error_message]
    self.notices_count = options[:notices_count] 
    self.most_recent_notice = options[:most_recent_notice]
    self.created_at = options[:created_at]
    self.id = options[:id]
  end

  # capture high-volume issues
  # capture very old issues
  def score
    Math.log(self.notices_count.to_f) * (1 / Math.log(time_since_last_error))
  end

  # Determine the age of the exception (based on when it was created)
  def age
    unless @age
      if self.created_at.nil?
        @age = 0
      else
        now = DateTime.now.to_time.to_i
        created_at = self.created_at.to_time.to_i
        @age = now - created_at
      end
    end

    @age
  end

  def time_since_last_error
    if self.most_recent_notice.nil?
      @time_since_last_error = 0 
    else
      now = DateTime.now.to_time.to_i
      last = self.most_recent_notice.to_time.to_i
      @time_since_last_error = now - last
    end

    @time_since_last_error
  end

  def process_backtrace!(group)
    backtraces = group.css('backtrace line').map {|e| e.content} 

    backtraces.each do |line|
      line.gsub!(/\[PROJECT_ROOT\]\//, "")

      if line =~ /^(?:app)/
        m = /^(?<path>.+)\:(?<line>[[:digit:]]+):in/.match(line)

        unless m.nil?
          self.file = m[:path]
          self.line = m[:line]
        end
        break
      end
    end

  end

  def self.parse_from_node(group)
    e = new({
          :error_class => group.css('error-class').first.content,
          :error_message => group.css('error-message').first.content,
          :notices_count => group.css('notices-count').first.content.to_i,
          :most_recent_notice => DateTime.parse(group.css('most-recent-notice-at').first.content),
          :created_at => DateTime.parse(group.css('created-at').first.content),
          :id => group.css('id').first.content.to_i
    })
      
    e
  end
end
