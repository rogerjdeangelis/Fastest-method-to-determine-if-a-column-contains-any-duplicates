SAS-L Fastest method to determine if a column contains any duplicates

  SOAPBOX ON (When to use a HASH)

    1. When you can't use mutiple threads or parallelize the data (HASH is single threaded)
    2. When you need to do complex processing of HASH table
    3. When processing is much more expensive than building  HASH table
    4. I did post a technique that allows the HASH table to persist(DOSUBL)
       for mutiple proc processing.

  SOAPBOX OFF

  Assumption - the data is sorted on key 1-80,000,000, there is a duplicate
  value 10,000,000 starting at 10,000,000 ie

   WORK.BIN ( One column 80,000,008 rows)

     I
    ===
     1
     2
     3
     ...
     10000000
     10000000
     10000001
     10000002
     ...
     80000000

related to
https://communities.sas.com/t5/General-SAS-Programming/Fastest-way-to-count-number-of-duplicates/td-p/392793

Very data dependent, a binary search for the consecutive dups should be faster than any of these methods.


   TIMINGS  (in seconds may be some caching did mutiple runs and R ran batch)
   =========================================

                   LOAD DATA       FIND FIRST DUP

   R (non HASH)       2.39              1.98

   SAS HASH          81.41              6.50

   SAS FIRST.DOT       NA               1.38  (only has to read 1/8th of the data)

   SORT(noUiqueKey)    NA              58.98

   PROC SQL            NA              28.99 (did not request a HASH - was multi-threded)



HAVE
====

   WORK.BIN with 80,000,008 observations (dups at 10, 20 ..80 million)
     I
    ===
     1
     2
     3
     ...

     10000000   Here is th first dup
     10000000

     10000001
     10000002
     ...
     80000000

WANT
====

   Basically I just want to know if rows are unique)

    10000000   * this is the first


*                _               _       _
 _ __ ___   __ _| | _____     __| | __ _| |_ __ _
| '_ ` _ \ / _` | |/ / _ \   / _` |/ _` | __/ _` |
| | | | | | (_| |   <  __/  | (_| | (_| | || (_| |
|_| |_| |_|\__,_|_|\_\___|   \__,_|\__,_|\__\__,_|

;


filename bin "d:/bin/binmat.bin" lrecl=32000 recfm=f;
data _null_ bin;
  file bin ;
   do i=1 to 80000000;
    if mod(i,10000000)=0 then do; output; put i rb8. @ ; end;
    put i rb8. @ ;
    output;
  end;
run;quit;


*                 _               _
 ___  __ _ ___   | |__   __ _ ___| |__
/ __|/ _` / __|  | '_ \ / _` / __| '_ \
\__ \ (_| \__ \  | | | | (_| \__ \ | | |
|___/\__,_|___/  |_| |_|\__,_|___/_| |_|

;

/** option 1: single data step using hash */
data want_opt1(keep=i);
  retain start 0;
  if 0 then set bin;
  dcl hash h1(multidata:'y', ordered:'y', hashexp:10, dataset:'bin');
  h1.defineKey('i');
  h1.defineDone();
  dcl hiter hh1('h1');

   /* Iterate through the hash object and output data values */
  length r 8;
  rc = hh1.first();
  start=datetime();
  do while (rc = 0);
    h1.check();
    h1.has_next(result:r);
    if r>0 then do;
        output;
        secs=datetime()-start;
        put secs=;
        stop;
    end;
    rc = hh1.next();
  end;
  secs=datetime()-start;
  put secs=;
  stop;
run;

NOTE: There were 80000008 observations read from the data set WORK.BIN.
SECS=6.5040001869
NOTE: The data set WORK.WANT_OPT1 has 1 observations and 1 variables.
NOTE: DATA statement used (Total process time):
      real time           1:21.42
      user cpu time       1:16.12
      system cpu time     5.14 seconds
      memory              9747310.39k
      OS Memory           9774864.00k
      Timestamp           10/23/2017 03:39:32 PM
      Step Count          387  Switch Count  1

*____
|  _ \
| |_) |
|  _ <
|_| \_\

;

%utl_submit_r64('
read.from <- file("d:/bin/binmat.bin", "rb");
vector.doubles <- readBin(read.from, n=80000000, "double");
close(read.from);
ptm <- proc.time();
vector.doubles[anyDuplicated(vector.doubles)];
proc.time() - ptm;
');

NOTE: DATA statement used (Total process time):
      real time           4.19 seconds

1] 1e+07
  user  system elapsed
  1.80    0.18    1.98

*____   ___  ____ _____
/ ___| / _ \|  _ \_   _|
\___ \| | | | |_) || |
 ___) | |_| |  _ < | |
|____/ \___/|_| \_\|_|

;

/** option 2: proc sort and data step **/
proc sort data=bin(keep=i) out=inter nouniquekey;
  by i;
run;

NOTE: There were 80000008 observations read from the data set WORK.BIN.
NOTE: 79999992 observations with unique key values were deleted.
NOTE: The data set WORK.INTER has 16 observations and 1 variables.
NOTE: PROCEDURE SORT used (Total process time):
      real time           23.85 seconds
      user cpu time       58.95 seconds
      system cpu time     8.48 seconds
      memory              71744.43k
      OS Memory           99128.00k
      Timestamp           10/23/2017 03:43:00 PM
      Step Count          392  Switch Count  3

* __ _          _        _       _
 / _(_)_ __ ___| |_   __| | ___ | |_
| |_| | '__/ __| __| / _` |/ _ \| __|
|  _| | |  \__ \ |_ | (_| | (_) | |_
|_| |_|_|  |___/\__(_)__,_|\___/ \__|

;

data first_dot;
  set bin;
  by i;
  if not (first.i and last.i) then do;output;stop;end;
run;

NOTE: There were 10000001 observations read from the data set WORK.BIN.
NOTE: The data set WORK.FIRST_DOT has 1 observations and 1 variables.
NOTE: DATA statement used (Total process time):
      real time           1.38 seconds
      user cpu time       1.06 seconds
      system cpu time     0.32 seconds
      memory              2335.09k
      OS Memory           30464.00k
      Timestamp           10/23/2017 03:44:55 PM
      Step Count          395  Switch Count  0

*____   ___  _
/ ___| / _ \| |
\___ \| | | | |
 ___) | |_| | |___
|____/ \__\_\_____|

;

/** option 3: Proc SQL with Group By and Having **/
proc sql noprint;
   create table group_by as
   select i, count(*) as num
   from bin
   group by i
   having num > 1;
quit;

NOTE: Table WORK.GROUP_BY created, with 8 rows and 2 columns.

2866  quit;
NOTE: PROCEDURE SQL used (Total process time):
      real time           27.99 seconds
      user cpu time       51.68 seconds
      system cpu time     4.64 seconds
      memory              72469.93k
      OS Memory           99924.00k
      Timestamp           10/23/2017 03:47:05 PM
      Step Count                        399  Switch Count  1




