require "language/node"

class Emscripten < Formula
  desc "LLVM bytecode to JavaScript compiler"
  homepage "https://emscripten.org/"
  # Emscripten is available under 2 licenses, the MIT license and the
  # University of Illinois/NCSA Open Source License.
  license "MIT"

  stable do
    url "https://github.com/emscripten-core/emscripten/archive/1.40.1.tar.gz"
    sha256 "e15ad7ffa1cce35c25cac7c797d6daa0c5868905eaaf5ed1431a8228b8803dfc"

    resource "fastcomp" do
      url "https://github.com/emscripten-core/emscripten-fastcomp/archive/1.40.1.tar.gz"
      sha256 "c34868ab566e9f073df319d9872608cef47ed1ea74852acacb12a22fd7c99a4c"
    end

    resource "fastcomp-clang" do
      url "https://github.com/emscripten-core/emscripten-fastcomp-clang/archive/1.40.1.tar.gz"
      sha256 "9ce4612df39684348d78acb711ec10bee98ad4ac136fb0dcb70d4c884b8bb6b3"
    end
  end

  livecheck do
    url :head
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    cellar :any
    sha256 "ac8892b0aba032f395821b0141c58ca952499df9b05902ec64dacfd4b4be8831" => :catalina
    sha256 "4915b3e0d93807bf0cbe42dfd9ddf6b6df93441c7560fd7857515e3bb8948fc0" => :mojave
    sha256 "e6b1f5a22fa597b045cdd52bf16a49892c227a27a84a0f16adfa4745b662ac6a" => :high_sierra
  end

  head do
    url "https://github.com/emscripten-core/emscripten.git"

    resource "fastcomp" do
      url "https://github.com/emscripten-core/emscripten-fastcomp.git"
    end

    resource "fastcomp-clang" do
      url "https://github.com/emscripten-core/emscripten-fastcomp-clang.git"
    end
  end

  depends_on "cmake" => :build
  depends_on "binaryen"
  depends_on "node"
  depends_on "python@3.8"
  depends_on "yuicompressor"

  def install
    ENV.cxx11

    # All files from the repository are required as emscripten is a collection
    # of scripts which need to be installed in the same layout as in the Git
    # repository.
    libexec.install Dir["*"]

    (buildpath/"fastcomp").install resource("fastcomp")
    (buildpath/"fastcomp/tools/clang").install resource("fastcomp-clang")

    cmake_args = std_cmake_args.reject { |s| s["CMAKE_INSTALL_PREFIX"] }
    cmake_args = [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DCMAKE_INSTALL_PREFIX=#{libexec}/llvm",
      "-DLLVM_TARGETS_TO_BUILD='X86;JSBackend'",
      "-DLLVM_INCLUDE_EXAMPLES=OFF",
      "-DLLVM_INCLUDE_TESTS=OFF",
      "-DCLANG_INCLUDE_TESTS=OFF",
      "-DOCAMLFIND=/usr/bin/false",
      "-DGO_EXECUTABLE=/usr/bin/false",
    ]

    mkdir "fastcomp/build" do
      system "cmake", "..", *cmake_args
      system "make"
      system "make", "install"
    end

    cd libexec do
      system "npm", "install", *Language::Node.local_npm_install_args
      rm_f "node_modules/ws/builderror.log" # Avoid references to Homebrew shims
    end

    %w[em++ em-config emar emcc emcmake emconfigure emlink.py emmake
       emranlib emrun emscons].each do |emscript|
      (bin/emscript).write_env_script libexec/emscript, PYTHON: Formula["python@3.8"].opt_bin/"python3"
    end
  end

  def post_install
    system bin/"emcc"
    inreplace "#{libexec}/.emscripten" do |s|
      s.gsub! /^(LLVM_ROOT.*)/, "#\\1\nLLVM_ROOT = \"#{opt_libexec}/llvm/bin\"\\2"
      s.gsub! /^(BINARYEN_ROOT.*)/, "#\\1\nBINARYEN_ROOT = \"#{Formula["binaryen"].opt_prefix}\"\\2"
    end
  end

  test do
    # Fixes "Unsupported architecture" Xcode prepocessor error
    ENV.delete "CPATH"

    (testpath/"test.c").write <<~EOS
      #include <stdio.h>
      int main()
      {
        printf("Hello World!");
        return 0;
      }
    EOS

    system bin/"emcc", "test.c", "-o", "test.js", "-s", "NO_EXIT_RUNTIME=0"
    assert_equal "Hello World!", shell_output("node test.js").chomp
  end
end
