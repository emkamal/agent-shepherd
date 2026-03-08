- [x] improve codex interactive detection
Right now, if we exit codex interactive session, the table will show ERROR on the status column. We should instead detect that codex interactive session has been exited and show exited on the state colum.

- [ ] add cost column after time_active column
when codex has been exited, it will emit this message:

Token usage: total=6,876,322 input=6,235,172 (+ 156,815,744 cached) output=641,150 (reasoning 317,467)
To continue this session, run codex resume 019cc55e-c2d9-7972-8ba7-81b34683336d

parse that input, cached and output value. load the pricing value in `price-list.csv`. then calculate the total cost for the session and put the value in cost column

- [ ]
