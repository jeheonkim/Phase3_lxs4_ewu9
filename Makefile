CC = gcc
CFLAGS = -I./src -std=gnu99 -g

LEX=lex

YACC=yacc
YFLAGS=-v -d -b obj/y
GRAMMAR=parser.y

# parser.y and strtab.c ship empty on purpose: Phase 3 starts from your own
# Phase 2 files. Say so plainly instead of letting yacc report end-of-file.
STARTER_CHECK = @for f in src/parser.y src/strtab.c; do test -s $$f || { echo "$$f is empty. Copy your Phase 2 $$(basename $$f) into src/ first (README.md, What you bring forward from Phase 2)."; missing=1; }; done; test -z "$$missing"

obj/mcc: obj/lex.yy.o obj/y.tab.o obj/tree.o obj/driver.o obj/strtab.o | obj
	$(CC) $(CFLAGS) -o $@ $^ -ll

obj/y.tab.o: obj/y.tab.c | obj
	$(CC) $(CFLAGS) -c $< -o $@

obj/lex.yy.o: obj/lex.yy.c | obj
	$(CC) $(CFLAGS) -c $< -o $@

obj/y.tab.h obj/y.tab.c: src/$(GRAMMAR)  src/tree.h | obj
	$(STARTER_CHECK)
	$(YACC) $(YFLAGS) $<

obj/lex.yy.c: src/scanner.l obj/y.tab.h | obj
	$(LEX) -o $@ $<

obj/tree.o: src/tree.c src/tree.h | obj
	$(CC)  $(CFLAGS) -c $< -o $@

obj/driver.o: src/driver.c src/tree.h obj/y.tab.h | obj
	$(CC)  $(CFLAGS) -c $< -o $@

obj/strtab.o: src/strtab.c src/strtab.h obj/y.tab.h | obj
	$(STARTER_CHECK)
	$(CC)  $(CFLAGS) -c $< -o $@

.PHONY: clean test objdir

obj:
	@mkdir -p obj

clean:
	@rm -rf obj
	@rm -f lex.yy.* *.o *~ scanner

test: obj/mcc
	@python3 test/run_tests.py --program obj/mcc $(ARGS)
