require_relative 'captcha'
require_relative '../utility/logging'

require 'phashion'
require 'chunky_png'

class Faucet::Captcha::Classic < Faucet::Captcha::Captcha
  include Faucet::Utility::Logging

  Pattern = Struct.new(:phash, :width, :height)

  MAX_HAMMING_DISTANCE = 2

  def self.logger
    Faucet::Utility::Logging.logger_for(self.name)
  end

  def self.patterns
    return @patterns if @patterns
    @patterns = Dir.glob(File.join(patterns_path, 'classic_pattern-*.png')).map do |path|
      image = ChunkyPNG::Image.from_file(path)
      Pattern.new(Phashion.image_hash_for(path), image.width, image.height)
    end
    logger.debug { 'Captcha pattern initialized.' }
    @patterns
  end

  def self.recognize(image)
    patterns.each do |pattern|
      begin
        tmp = Tempfile.new(['captcha', '.png'])
        image.crop(0, 0, pattern.width, pattern.height).write(tmp)
        tmp.close
        image_hash = Phashion.image_hash_for(tmp.path)
        hamming_distance = Phashion.hamming_distance(pattern.phash, image_hash)
        logger.debug { 'Captcha recognition - hamming distance: %d.' % [hamming_distance] }
        return new(image) if hamming_distance <= MAX_HAMMING_DISTANCE
      ensure
        tmp.unlink
      end
    end
    nil
  end

  attr_reader :image

  def initialize(image)
    @image = image
    # 400 = a + b
    # a/300 = b/150 => a*150/300 = b
    # 400 = a(1 + 150/300)
    # a = 400 / 1.5
  end
end
