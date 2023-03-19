all: tidy out/metallll

out/metallll: main.m
	@ mkdir -p out
	@ clang \
		-O3 \
		-flto \
		-framework Cocoa \
		-framework QuartzCore \
		-framework Metal \
		-framework MetalKit \
		-o $@ \
		$^

tidy: main.m
	@ clang-format -i $^

clean:
	@ rm -r out

.PHONY: clean
