;;;;DenemoPlayCursorToEnd
(if (and (d-PlayAlongActive) (Rest?))
	(d-WarningDialog "Cannot start playalong from rest")
	(begin
		(d-CreateTimebase)
		(d-SetPlaybackInterval (d-GetMidiOnTime) -1)
		(DenemoPlay)))