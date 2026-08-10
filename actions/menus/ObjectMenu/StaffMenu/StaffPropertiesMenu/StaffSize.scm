;;;StaffSize
(let ((tag "StaffSize") (size #f))
  (if (d-Directive-staff? "ChordStaff")
	(d-WarningDialog "Cannot set staff size on Chord Staffs")
	(begin
		(set! size (d-DirectiveGet-staff-data tag))
		(set! size (d-GetUserInput (_ "Setting Staff Size") (_ "Give Staff Size magnification (for printing), 0 for default") (if size size "0")))		
		(if (equal? size "0")
			(d-DirectiveDelete-staff tag)	
			(if (and size (string->number size))
				(begin
				  (if (d-Directive-staff? tag)
					(d-DirectiveDelete-staff tag))
				  (ToggleDirective "staff" "prefix" tag (string-append "
						   fontSize = #" size "
						   \\override VerticalAxisGroup.minimum-Y-extent = #'(0 . 0)
						   \\override StaffSymbol.staff-space = #(magstep " size ")\n ") (logior DENEMO_OVERRIDE_AFFIX DENEMO_ALT_OVERRIDE))
				  (d-DirectivePut-staff-data tag size))
				 (d-WarningDialog "Cancelled"))))))