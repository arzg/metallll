all: tidy out/metallll

out/metallll: main.m out/shaders.metallib
	@ mkdir -p out
	@ clang \
		-fobjc-arc \
		-O3 \
		-flto \
		-framework Cocoa \
		-framework QuartzCore \
		-framework Metal \
		-framework MetalKit \
		-o $@ \
		$<
	@ mkdir -p out/metallll.app/Contents/MacOS
	@ mkdir -p out/metallll.app/Contents/Resources
	@ cp out/metallll out/metallll.app/Contents/MacOS/metallll
	@ cp out/shaders.metallib out/metallll.app/Contents/Resources/shaders.metallib

out/shaders.metallib: shaders.metal
	@ mkdir -p out
	@ xcrun -sdk macosx metal $^ -o $@

tidy: main.m shaders.metal
	@ clang-format -i $^

clean:
	@ rm -r out

.PHONY: clean
