require 'chunky_png'

require_relative '../utility/logging'

class Plunder
  module Captcha
    class Simplifier
      include Plunder::Utility::Logging

      SETUP = {
          histogram_cut: 0.02,
          linear_cut_range: [1.0 / 3, 2.0 / 3].freeze,
          avg_color_distance: 0.02,
          max_color_distance: 0.06,
          margin_px: 8
      }.freeze

      def simplify_image!(image)
        before = [image.width, image.height]
        simplify!(image)
        crop!(image)
        after = [image.width, image.height]
        if before == after
          logger.debug { 'Image size of [%dx%d] px not reduced.' % after }
        else
          logger.debug { 'Image size reduced from [%dx%d] px to [%dx%d] px.' % [*before, *after] }
        end
        image
      end

      private

      def simplify!(image)
        saturation = histogram_cut!(image.pixels.map { |px| ChunkyPNG::Color.to_hsv(px)[1] })
        lightness = histogram_cut!(image.pixels.map { |px| 1.0 - ChunkyPNG::Color.to_hsl(px)[2] })
        avg = histogram_cut!(saturation.zip(lightness).map! { |spx, lpx| (spx + 2 * lpx) / 3 }, SETUP[:histogram_cut] * 10)

        min, max = SETUP[:linear_cut_range]
        gap = max - min
        transform_factor = ->(px) do
          return 0 if px < min
          return 1 if px > max
          (px - min) / gap
        end
        avg.map! do |px|
          px = 1.0 - px * transform_factor.call(px)
          ChunkyPNG::Color.grayscale((px * 255).round)
        end
        image.pixels[0, image.pixels.size] = avg

        image
      end

      def crop!(image)
        max_color_dist = ChunkyPNG::Color.euclidean_distance_rgba(ChunkyPNG::Color::BLACK, ChunkyPNG::Color::WHITE)
        max_avg_px_dist = max_color_dist * SETUP[:avg_color_distance]
        max_single_px_dist = max_color_dist * SETUP[:avg_color_distance]
        crop = [0, 1, 2, 3]
        crop.map! do |crop_idx|
          size = crop_idx.even? ? image.width : image.height
          last_idx = 0
          (0...size).each do |idx|
            last_idx = idx
            idx = size - idx - 1 if crop_idx > 1
            avg = 0
            all = true
            vector = crop_idx.even? ? image.column(idx) : image.row(idx)
            vector.each do |px|
              next if px == ChunkyPNG::Color::WHITE
              dist = ChunkyPNG::Color.euclidean_distance_rgba(px, ChunkyPNG::Color::WHITE)
              avg += dist
              all = false if dist > max_single_px_dist
            end
            avg /= image.width + image.height
            break unless all || avg <= max_avg_px_dist
          end
          last_idx < SETUP[:margin_px] ? 0 : last_idx - SETUP[:margin_px]
        end
        [2, 3].each do |idx|
          size = idx.even? ? image.width : image.height
          crop[idx] = size - crop[idx] - crop[idx - 2]
          if crop[idx] < 1
            logger.warn { 'Image considered as blank after simplifying. Not cropping.'}
            return image
          end
        end
        image.crop!(*crop)
      end

      def histogram_cut!(pixels, bottom = SETUP[:histogram_cut], top = SETUP[:histogram_cut])
        sorted = pixels.sort
        min, max = sorted[(bottom * pixels.size).round], sorted[-(top * pixels.size).round - 1]
        max -= min
        return pixels if max < 0.001
        pixels.map! do |px|
          px = (px - min) / max
          px = 1.0 if px > 1.0
          px = 0.0 if px < 0.0
          px
        end
      end
    end
  end
end
