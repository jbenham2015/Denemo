;;AllowBreakAtHalfBar   
(d-GoToBeginning)
        (let ((ticks (/ (GetMeasureTicks) 2)))
        (while (d-NextNote)
            (if (eq? (d-GetStartTick) ticks)
                (begin 
                    (d-AllowLineBreak 'non-interactive)
                    (d-MoveCursorRight)))))
(let ((tag "AllowBreakAtHalfBar"))                   
	(d-DirectivePut-score-override tag DENEMO_OVERRIDE_AFFIX)
	(d-DirectivePut-score-display tag "AllowBreakAtHalfBar")           
	(d-DirectivePut-score-prefix tag "\n#(define-public ((every-nth-bar-number-visible-except-first n) barnum mp)
				(and (> barnum 1) (= 0 (modulo barnum n))))\n\\layout {\\context {\\Score 
				barNumberVisibility = #(every-nth-bar-number-visible-except-first 1) 
				\\override Score.BarNumber.break-visibility = #begin-of-line-visible }}\n"))                   
