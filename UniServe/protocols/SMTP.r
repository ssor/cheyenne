REBOL [
	Title: "SMTP Async Protocol"
	Author: "SOFTINNOV / Nenad Rakocevic"
	Version: 1.0.1
	Date: 18/02/2010
]

install-protocol [
	name: 'SMTP
	port-id: 25
	verbose: 0
	connect-retries: 4
		
	stop-at: crlf
	whoami: system/network/host
	
	get-params: does [stop-at: "250 "]
	reset: 		does [stop-at: crlf]
	
	fire-event: does [on-sent server]
	
	on-connected: does [
		server/timeout: 00:05		; 5 mn (RFC)
		server/user-data: context [
			state: 'ehlo
			id: random 99999999
		]
		stop-at: crlf
	]
	
	on-received: func [data /local su action job s][
		job: server/task/job
		su: server/user-data
		if verbose > 2 [log/info trim/tail reform [su/id ">>" as-string data]]
		if verbose > 1 [log/info [su/id " state = " su/state]]
		
		either action: select [
			helo ["220" [["HELO " whoami crlf]] mail]
			ehlo ["220" [["EHLO " whoami crlf] get-params] ext1]
			ext1 ["250" [reset] ext2]
			ext2 [  -   [["MAIL FROM:<" job/from "> BODY=8BITMIME" crlf]] rcpt]
			mail ["250" [["MAIL FROM:<" job/from "> BODY=8BITMIME" crlf]] rcpt]
			rcpt ["250" [["RCPT TO:<" server/task/to #">" crlf]] data]
			data ["250" ["DATA^M^/"] body]
			body ["354" [[%outgoing/ job/body] "^M^/.^M^/"] sent]
			sent ["250" ["QUIT^M^/"] quit]
			quit ["221" [fire-event] closed]
		] su/state [
			either any [action/1 = '- find/part data action/1 3][
				foreach s action/2 [
					s: any [all [block? s rejoin s] :s]
					if all [0 < verbose verbose < 3][log/info rejoin [su/id " request >> " s]]
					either word? s [do s][
						if verbose > 2 [log/info trim/tail reform [su/id "<<" as-string s]]
						write-server s
					]
				]
				su/state: action/3
			][
				close-server
				on-error server as-string data
				stop-at: none
			]
		][
			log/error reform ["unknown state" mold su/state]
		]
	]
		
	events: [
		on-sent		; [port]
		on-error	; [port reason [string!]]
	]
]



