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

out/shaders.metallib: shaders.metal
	@ mkdir -p out
	@ xcrun -sdk macosx metal $^ -o $@

tidy: main.m shaders.metal
	@ clang-format -i $^

clean:
	@ rm -r out

.PHONY: clean
