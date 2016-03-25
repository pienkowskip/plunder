# Plunder

Various online money-making bots. Uses Capybara, PhantomJS & external captcha solving service to headlessly claim
rewards in online money-making systems.

## Installation

Add this line to your application's Gemfile:

    gem 'plunder'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install plunder

### Prerequirements

#### Tesseract OCR gem

Gem `tesseract-ocr` requires Debian packages: `libleptonica-dev` and `libtesseract-dev`.
Additionally you will need language package `tesseract-ocr-eng`.

Probably you will need to setup `TESSDATA_PREFIX` environment var to directory with languages files.

#### Phashion gem

To build native extension for `phashion` gem you need to install Debian packages: `libjpeg-dev` and `libpng-dev`.

#### PhantomJS

Headless browser (Poltergeist) requires JavaScript engine binary.
I recommend PhantomJS which can be downloaded from <http://phantomjs.org/download.html>.

## Usage

TODO: Write instructions here.

## Contributing

TODO: Write instructions here.

