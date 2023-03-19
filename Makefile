all: tidy out/metallll

out/metallll: main.m
	@ mkdir -p out
	@ clang \
		-framework Cocoa \
		-framework QuartzCore \
		-framework Metal \
		-o $@ \
		$^

tidy: main.m
	@ clang-format -i $^

clean:
	@ rm -r out

.PHONY: clean
