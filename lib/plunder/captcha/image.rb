require 'phashion'

require_relative 'base'

class Plunder::Captcha::Image < Plunder::Captcha::Base

  Pattern = Struct.new(:name, :phash, :position, :crop)

  PATTERNS = [
      ['enter_the_following.png', [0, 0], [5, 20, 5, 3]],
      ['enter_the_answer.png', [0, 84], [3, 98, 3, 3]]
  ].freeze
  PATTERNS_DIR = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'var', 'captcha_image_patterns')).freeze

  def initialize(dm, image_decoder)
    super(dm)
    @image_decoder = image_decoder
  end

  def solve(element)
    return false unless element.tag_name == 'img'
    logger.debug { 'Captcha recognized as image. Starting solving.' }
    image = element_image(element)
    pattern = patterns.find { |p| recognize(image, p) }
    if pattern
      logger.debug { 'Recognized [%s] pattern in captcha image.' % pattern.name }
    else
      logger.warn { 'Captcha image has unknown pattern. Trying to solve anyway.' }
    end
    crop = pattern ? pattern.crop : [3, 3, 3, 3]
    image.crop!(crop[0], crop[1], image.width - crop[0] - crop[2], image.height - crop[1] - crop[3])
    @image_decoder.decode(image)
  end

  def answer_rejected
    @image_decoder.answer_rejected if @image_decoder.respond_to?(:answer_rejected)
  end

  private

  def recognize(image, pattern)
    tmp = Tempfile.new(['captcha', '.png'])
    image.crop(*pattern.position).write(tmp)
    tmp.close
    image_hash = Phashion.image_hash_for(tmp.path)
    Phashion.hamming_distance(pattern.phash, image_hash) <= Phashion::Image::DEFAULT_DUPE_THRESHOLD
  ensure
    tmp.unlink
  end

  def patterns
    return @patterns if @patterns
    @patterns = PATTERNS.map do |filename, pos, crop|
      path = File.join(PATTERNS_DIR, filename)
      image = ChunkyPNG::Image.from_file(path)
      Pattern.new(filename.chomp('.png'), Phashion.image_hash_for(path), [pos[0], pos[1], image.width, image.height], crop)
    end
    logger.debug { 'Captcha images patterns initialized.' }
    @patterns.freeze
  end
end
