require 'strscan'
require 'cgi'

# This class was copied/adapted from ActionController
class UrlEncodedPairParser < StringScanner
  attr_reader :top, :parent, :result

  def initialize(pairs = [])
    super('')
    @result = {}
    pairs.each { |key, value| parse(key, value) }
  end

  KEY_REGEXP = %r{([^\[\]=&]+)}
  BRACKETED_KEY_REGEXP = %r{\[([^\[\]=&]+)\]}

  # Parse the query string
  def parse(key, value)
    self.string = key
    @top, @parent = result, nil

    # First scan the bare key
    key = scan(KEY_REGEXP) or return
    key = post_key_check(key)

    # Then scan as many nestings as present
    until eos?
      r = scan(BRACKETED_KEY_REGEXP) or return
      key = self[1]
      key = post_key_check(key)
    end

    bind(key, value)
  end

  private
  def post_key_check(key)
    if scan(/\[\]/)
      container(key, Array)
      nil
    elsif check(/\[[^\]]/)
      container(key, Hash)
      nil
    else
      key
    end
  end

  def container(key, klass)
    type_conflict! klass, top[key] if top.is_a?(Hash) && top.key?(key) && ! top[key].is_a?(klass)
    value = bind(key, klass.new)
    type_conflict! klass, value unless value.is_a?(klass)
    push(value)
  end

  def push(value)
    @parent, @top = @top, value
  end

  def bind(key, value)
    if top.is_a? Array
      if key
        if top[-1].is_a?(Hash) && ! top[-1].key?(key)
          top[-1][key] = value
        else
          top << {key => value}
          push top.last
          value = top[key]
        end
      else
        top << value
      end
    elsif top.is_a? Hash
      key = CGI.unescape(key)
      parent << (@top = {}) if top.key?(key) && parent.is_a?(Array)
      top[key] ||= value
      return top[key]
    else
      raise ArgumentError, "Don't know what to do: top is #{top.inspect}"
    end

    return value
  end

  def type_conflict!(klass, value)
    raise TypeError, "Conflicting types for parameter containers."
  end
end
