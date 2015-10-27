require 'phashion'

require_relative 'base'
require_relative 'imageable'

class Plunder::Captcha::Image < Plunder::Captcha::Base
  include Plunder::Captcha::Imageable

  Pattern = Struct.new(:phash, :width, :height)

  VAR_PATH = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'var')).freeze

  def initialize(dm)
    super
    imageable_initialize(dm)
  end

  def solve(element)
    return false unless element.tag_name == 'img'
    logger.debug { 'Captcha recognized as image. Starting solving.' }
    image = element_render(element)
    if recognize(image)
      image.crop!(5, pattern.height + 2, image.width - 2 * 5, image.height - 3 - pattern.height - 2)
    else
      image.crop!(3, 3, image.width - 2 * 3, image.height - 2 * 3)
      logger.warn { 'Captcha image has unknown pattern. Trying to solve anyway.' }
    end
    solve_captcha_image(image)
  end

  private

  def recognize(image)
    tmp = Tempfile.new(['captcha', '.png'])
    image.crop(0, 0, pattern.width, pattern.height).write(tmp)
    tmp.close
    image_hash = Phashion.image_hash_for(tmp.path)
    hamming_distance = Phashion.hamming_distance(pattern.phash, image_hash)
    logger.debug { 'Image captcha recognition - hamming distance: %d.' % [hamming_distance] }
    hamming_distance <= Phashion::Image::DEFAULT_DUPE_THRESHOLD
  ensure
    tmp.unlink
  end

  def pattern
    return @pattern if @pattern
    path = File.join(VAR_PATH, 'image_captcha_pattern.png')
    image = ChunkyPNG::Image.from_file(path)
    @pattern = Pattern.new(Phashion.image_hash_for(path), image.width, image.height)
    logger.debug { 'Image captcha pattern initialized.' }
    @pattern
  end
end
