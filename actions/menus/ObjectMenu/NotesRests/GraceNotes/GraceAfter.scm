;;GraceAfter
(let ((tag "GraceAfter"))
  (if (d-Directive-chord? tag)
	(begin 
		(d-DirectiveDelete-chord tag) 
		(d-WarningDialog (_ "Grace(s) detached")))
	(begin	
      (if (not (d-IsGrace))
		(d-MoveCursorRight))
	  (if (d-IsGrace)
        (let ((pos (d-GetUserInput (_ "Attach Grace Notes") (_ "Give fractional position") "3/4")))
			(if pos
				(begin
					(set! pos (string->number pos))
					(if (and (exact? pos) (< pos 1) (> pos 0))
						(begin
							(while (and (d-IsGrace) (d-MoveCursorLeft)))
							(if ( not (d-IsGrace))
								(if (d-Directive-chord? tag)
									(d-DirectiveDelete-chord tag)
									(begin
										(d-PushPosition)
										(d-DirectivePut-chord-prefix tag (string-append "\\attachGraces #" (number->string pos) " "))
										(d-DirectivePut-chord-display tag (_ "Grace(s) Attached"))
										(d-DirectivePut-chord-override tag DENEMO_OVERRIDE_AFFIX)
										(d-DirectivePut-score-prefix tag "
#(define (after-grace-factor? x)
    (and (rational? x)
         (< 0 x 1)))

#(define (grace-music? m)
    (and (ly:music? m)
         (music-is-of-type? m 'grace-music)))

attachGraces =
#(define-music-function (frac note graces) (after-grace-factor?
ly:music? grace-music?)
     #{
       <<
         #note
         {
           \\skip $(make-duration-of-length (ly:music-length note)) * #frac
           #graces
         }
       >>
     #})
											")
											(d-DirectivePut-score-override tag DENEMO_OVERRIDE_AFFIX)
											(d-PopPosition)
											(d-SetSaved #f)))))
									(d-WarningDialog (_ "Not a fraction of the main note duration"))))
								(d-WarningDialog (_ "Cancelled"))))
		(d-WarningDialog (_ "Cursor not on Grace Note"))))))
