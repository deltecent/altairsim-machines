; "THE ENTERTAINER" BY SCOTT JOPLIN -- THE SAMPLE SCORE IN THE
; NEWTECH MODEL 6 MUSIC BOARD USERS MANUAL (REV. A, JUNE 1977).
;
; THE MANUAL GIVES THE SCORE AS NOTE STRINGS IN THE DATA LINES OF
; MICROSCORE, A NORTH STAR BASIC PROGRAM THAT WRITES THESE BYTES
; INTO MEMORY AT 100H. THE BYTES HERE ARE WHAT MICROSCORE'S OWN
; ARITHMETIC (LINES 560-680, TEMPO K6 = 1.2) GIVES FOR EACH STRING.
;
; THREE BYTES A NOTE: THE PITCH CONSTANT, THEN THE DURATION COUNT,
; LOW BYTE FIRST, WITH 1 ADDED TO THE HIGH BYTE. A ZERO PITCH ENDS
; THE SCORE.
;
; EACH LINE SHOWS ITS NOTE STRING: THE NOTE, A SHARP (#) OR A FLAT,
; THE OCTAVE (1 TO 3) AND THE LENGTH (S E Q H W, AND . FOR DOTTED).
; THE MANUAL WRITES A FLAT AS AN EXCLAMATION MARK. IT IS A SMALL b
; HERE, BECAUSE THIS ASSEMBLER ENDS A STATEMENT AT THAT MARK.
;
        ORG     0100H
;
; LINE 830
        DB      031H,03EH,001H    ;   1  D 3S
        DB      02BH,044H,001H    ;   2  E 3S
        DB      038H,036H,001H    ;   3  C 3S
        DB      044H,05CH,001H    ;   4  A 3E
        DB      03CH,034H,001H    ;   5  B 3S
        DB      04EH,052H,001H    ;   6  G 2E
; LINE 840
        DB      06AH,01EH,001H    ;   7  D 2S
        DB      05EH,022H,001H    ;   8  E 2S
        DB      078H,01CH,001H    ;   9  C 2S
        DB      090H,02EH,001H    ;  10  A 2E
        DB      07FH,01AH,001H    ;  11  B 2S
        DB      090H,016H,001H    ;  12  A 2S
        DB      099H,016H,001H    ;  13  Ab2S
; LINE 850
        DB      0A3H,052H,001H    ;  14  G 1Q
        DB      023H,0A4H,001H    ;  15  G 3E
        DB      0DBH,010H,001H    ;  16  D 1S
        DB      0CFH,010H,001H    ;  17  D#1S
; LINE 860
        DB      0C3H,012H,001H    ;  18  E 1S
        DB      078H,036H,001H    ;  19  C 2E
        DB      0C3H,012H,001H    ;  20  E 1S
        DB      078H,036H,001H    ;  21  C 2E
        DB      0C3H,012H,001H    ;  22  E 1S
        DB      078H,0A4H,001H    ;  23  C 2Q.
; LINE 870
        DB      038H,036H,001H    ;  24  C 3S
        DB      031H,03EH,001H    ;  25  D 3S
        DB      02EH,040H,001H    ;  26  D#3S
; LINE 880
        DB      02BH,044H,001H    ;  27  E 3S
        DB      038H,036H,001H    ;  28  C 3S
        DB      031H,03EH,001H    ;  29  D 3S
        DB      02BH,08AH,001H    ;  30  E 3E
; LINE 890
        DB      03CH,034H,001H    ;  31  B 3S
        DB      031H,07AH,001H    ;  32  D 3E
; LINE 900
        DB      038H,048H,002H    ;  33  C 3Q.
        DB      0DBH,010H,001H    ;  34  D 1S
        DB      0CFH,010H,001H    ;  35  D#1S
; LINE 910
        DB      0C3H,012H,001H    ;  36  E 1S
        DB      078H,036H,001H    ;  37  C 2E
        DB      0C3H,012H,001H    ;  38  E 1S
        DB      078H,036H,001H    ;  39  C 2E
        DB      0C3H,012H,001H    ;  40  E 1S
        DB      078H,0A4H,001H    ;  41  C 2Q.
; LINE 920
        DB      078H,01CH,001H    ;  42  C 2S
        DB      044H,02EH,001H    ;  43  A 3S
        DB      04EH,028H,001H    ;  44  G 2S
; LINE 930
        DB      053H,026H,001H    ;  45  F#2S
        DB      044H,02EH,001H    ;  46  A 3S
        DB      038H,036H,001H    ;  47  C 3S
        DB      02BH,08AH,001H    ;  48  E 3E
        DB      031H,03EH,001H    ;  49  D 3S
        DB      038H,036H,001H    ;  50  C 3S
        DB      044H,02EH,001H    ;  51  A 3S
; LINE 940
        DB      031H,070H,002H    ;  52  D 3Q.
        DB      0DBH,010H,001H    ;  53  D 1S
        DB      0CFH,010H,001H    ;  54  D#1S
; LINE 950
        DB      0C3H,012H,001H    ;  55  E 1S
        DB      078H,036H,001H    ;  56  C 2E
        DB      0C3H,012H,001H    ;  57  E 1S
        DB      078H,036H,001H    ;  58  C 2E
        DB      0C3H,012H,001H    ;  59  E 1S
        DB      078H,0A4H,001H    ;  60  C 2Q.
; LINE 960
        DB      038H,036H,001H    ;  61  C 3S
        DB      031H,03EH,001H    ;  62  D 3S
        DB      02EH,040H,001H    ;  63  D#3S
; LINE 970
        DB      02BH,044H,001H    ;  64  E 3S
        DB      038H,036H,001H    ;  65  C 3S
        DB      031H,03EH,001H    ;  66  D 3S
        DB      02BH,08AH,001H    ;  67  E 3E
        DB      03CH,034H,001H    ;  68  B 3S
        DB      031H,07AH,001H    ;  69  D 3E
; LINE 980
        DB      038H,048H,002H    ;  70  C 3Q.
        DB      038H,036H,001H    ;  71  C 3S
        DB      031H,03EH,001H    ;  72  D 3S
; LINE 990
        DB      02BH,044H,001H    ;  73  E 3S
        DB      038H,036H,001H    ;  74  C 3S
        DB      031H,03EH,001H    ;  75  D 3S
        DB      02BH,08AH,001H    ;  76  E 3E
        DB      038H,036H,001H    ;  77  C 3S
        DB      031H,03EH,001H    ;  78  D 3S
        DB      038H,036H,001H    ;  79  C 3S
; LINE 1000
        DB      02BH,044H,001H    ;  80  E 3S
        DB      038H,036H,001H    ;  81  C 3S
        DB      031H,03EH,001H    ;  82  D 3S
        DB      02BH,08AH,001H    ;  83  E 3E
        DB      038H,036H,001H    ;  84  C 3S
        DB      031H,03EH,001H    ;  85  D 3S
        DB      038H,036H,001H    ;  86  C 3S
; LINE 1010
        DB      02BH,044H,001H    ;  87  E 3S
        DB      038H,036H,001H    ;  88  C 3S
        DB      031H,03EH,001H    ;  89  D 3S
        DB      02BH,08AH,001H    ;  90  E 3E
        DB      03CH,034H,001H    ;  91  B 3S
        DB      031H,07AH,001H    ;  92  D 3E
; LINE 1020
        DB      038H,0DAH,001H    ;  93  C 3Q
        DB      038H,036H,001H    ;  94  C 3S
        DB      05EH,022H,001H    ;  95  E 2S
        DB      058H,024H,001H    ;  96  F 2S
        DB      053H,026H,001H    ;  97  F#2S
; LINE 1030
        DB      04EH,052H,001H    ;  98  G 2E
        DB      044H,02EH,001H    ;  99  A 3S
        DB      04EH,052H,001H    ; 100  G 2E
        DB      05EH,022H,001H    ; 101  E 2S
        DB      058H,024H,001H    ; 102  F 2S
        DB      053H,026H,001H    ; 103  F#2S
; LINE 1040
        DB      04EH,052H,001H    ; 104  G 2E
        DB      044H,02EH,001H    ; 105  A 3S
        DB      04EH,052H,001H    ; 106  G 2E
        DB      05EH,022H,001H    ; 107  E 2S
        DB      078H,01CH,001H    ; 108  C 2S
        DB      0A3H,014H,001H    ; 109  G 1S
; LINE 1050
        DB      090H,016H,001H    ; 110  A 2S
        DB      07FH,01AH,001H    ; 111  B 2S
        DB      078H,01CH,001H    ; 112  C 2S
        DB      06AH,01EH,001H    ; 113  D 2S
        DB      05EH,022H,001H    ; 114  E 2S
        DB      06AH,01EH,001H    ; 115  D 2S
        DB      078H,01CH,001H    ; 116  C 2S
        DB      06AH,01EH,001H    ; 117  D 2S
; LINE 1060
        DB      078H,036H,001H    ; 118  C 2E
        DB      0A3H,028H,001H    ; 119  G 1E
        DB      0F7H,01CH,001H    ; 120  C 1E
;
        DB      0               ; 121  X -- END OF SCORE
;
        END
