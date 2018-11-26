parser_fn = lua-parser
#CFLAGS=-O2 -DNDEBUG
CFLAGS = -Wall -g

lua2ljs: $(parser_fn).c
	$(CC) $(CFLAGS) -o $@ $<

$(parser_fn).c: $(parser_fn).ly lemon lempar.c $(parser_fn).re2c.c
	./lemon $<
	cat $(parser_fn).re2c.c >> $@

lemon: lemon.c
	$(CC) -o $@ lemon.c

%.re2c : #cancel implicit rule, do not attempt to find %.re2c.c
%.re2c.c : %.re2c
	re2c -Wundefined-control-flow $< -o $@

.PHONY: clean

clean:
	-rm lemon lua2ljs $(parser_fn).out $(parser_fn).[ch] $(parser_fn).re2c.c