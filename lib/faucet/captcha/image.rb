require 'phashion'

require_relative 'captcha'

class Faucet::Captcha::Image < Faucet::Captcha::Captcha
  Pattern = Struct.new(:phash, :width, :height)

  PATTERNS_PATH = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'var', 'captchas')).freeze

  def solve(element)
    return false unless element.tag_name == 'img'
    image = element_screenshot(element)
    logger.debug { 'Captcha recognized as image captcha. Starting solving.' }
    if recognize(image)
      image.crop!(5, pattern.height + 3, image.width - 2 * 5, image.height - 5 - pattern.height - 3)
    else
      image.crop!(3, 3, image.width - 2 * 3, image.height - 2 * 3)
      logger.warn { 'Captcha image has unknown pattern. Trying to solve anyway.' }
    end
    image.save('image_captcha-%s.png' % Time.new.strftime('%Y%m%dT%H%M%S')) #TODO: Solve (downsize & send to API) instead of saving.
    true
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
    path = File.join(PATTERNS_PATH, 'classic_pattern.png')
    image = ChunkyPNG::Image.from_file(path)
    @pattern = Pattern.new(Phashion.image_hash_for(path), image.width, image.height)
    logger.debug { 'Image captcha pattern initialized.' }
    @pattern
  end

  # 400 = a + b
  # a/300 = b/150 => a*150/300 = b
  # 400 = a(1 + 150/300)
  # a = 400 / 1.5
end
