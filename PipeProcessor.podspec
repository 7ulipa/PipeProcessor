Pod::Spec.new do |s|
  s.name             = 'PipeProcessor'
  s.version          = '0.0.2'
  s.summary          = 'Processor support pipe and cancel'

  s.description      = <<-DESC
  Processor support pipe and cancel, easy to use
                       DESC
  s.homepage         = 'https://github.com/7ulipa/PipeProcessor'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Tulipa' => 'darwin.jxzang@gmail.com' }
  s.source           = { :git => 'https://github.com/7ulipa/PipeProcessor.git', :tag => s.version }

  s.ios.deployment_target = '8.0'

  s.source_files = 'PipeProcessor/Classes/**/*'

end
