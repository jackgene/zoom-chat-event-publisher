JsOsaDAS1.001.00bplist00�Vscript_EObjC.import('Foundation')
ObjC.import('Cocoa')

let currApp = Application.currentApplication()
currApp.includeStandardAdditions = true

let SE = Application('System Events')
SE.includeStandardAdditions = true

let metadataText = ""
let pastLength = undefined
let dormant = false
let ZoomApp = SE.applicationProcesses.byName("zoom.us")

function isMeetingOngoing() {
	// the window "Zoom meeting" isn't reported if it's in a non-active Mission Control "Space"
	// so let's check whether Zoom's Window menu contains a "Zoom Meeting" menuItem
	try {
		ZoomApp.menuBars()[0].menuBarItems.byName("Window").menus.byName("Window").menuItems.byName("Zoom Meeting")()
	} catch (error) {
		return ZoomApp.windows.whose({ name: { _contains: 'Chat' } }).length == 1
	}
	return true
}

function getChatMessages(){
	// returns the number of lines in chat (including the name lines!)
	let messages = []
	let table
	let textRows

	// get content of detached chat window
	zwc = ZoomApp.windows.whose({ name: { _contains: 'Chat' } })
	if (zwc.length == 1) {
		// there is a chat window
		zwcs = zwc.splitterGroups[0]
		zwcss = zwcs.scrollAreas[0]
		table = zwcss.tables[0]
		textRows = table.rows
	} else {
		// get content of attached chat window
		zwc2 = ZoomApp.windows.whose({ name: { _contains: 'Zoom Meeting' } })

		sidepanel = zwc2.splitterGroups[0]
		chat_embedded = sidepanel.splitterGroups[0]
		if (chat_embedded()[0] == null) {
			// the chat panel is not where it should
			return null
		}

		table = chat_embedded.scrollAreas[0].tables[0]
		textRows = table.rows
	}
	let basePositionLeft = table.position()[0][0]
	for (let i = 0; i < textRows.length; i ++) {
		textRow = textRows[i].uiElements[0].uiElements[0]
		messages.push(
			{
				metadata: (textRow.position()[0][0] - basePositionLeft) == 57,
				text: textRow.value()[0]
			}
		)
	}

	return messages
}


function idle(){
	if (!isMeetingOngoing()) {
		if (!dormant) {
			// let's warn and go dormant
			past_length = undefined
			dormant = true
			//currApp.beep(1)
			currApp.displayNotification(
				"Waiting for any new meeting...",
				{withTitle:"No Zoom meeting detected"}
			)
		}
		return 10
	}
	dormant = false
	try {
		messages = getChatMessages()
	} catch (error) {
		SE.displayAlert("Unable to get the chat length", {
			message: "" + error + "Please check that the script is allowed in System Preferences " +
				"- Security & Privacy - Privacy - Accessibility.\n\nYou might need to " +
				"UNCHECK its checkbox and RE-CHECK it again.",
			as: "critical",
			buttons: ["Show me where"],
			defaultButton: "Show me where"
		})
		SP = Application("System Preferences")
	SP.panes.byId("com.apple.preference.security").anchors.byName("Privacy_Accessibility").reveal()
		SP.activate()
		ObjC.import('stdlib')
		$.exit(1)
	}
	if (messages == null) {
		//currApp.beep(1)
		currApp.displayNotification("Please open it to detect changes",
			{withTitle:"The chat window seems to be closed!"})
		return 3
	} else  {
		length = messages.length
		if (typeof pastLength == 'undefined'){
			currApp.displayNotification(
				"Currently contains " + length + " lines",
				{withTitle:"Tracking chat..."}
			)
			past_length = 0
		}
		if (length != pastLength) {
			//currApp.beep(3)
			let newMessages = messages.slice(pastLength)
			for (let i = 0, len = newMessages.length; i < len; ++i) {
				let newMessage = newMessages[i]
				if (newMessage.metadata) {
					metadataText = newMessage.text
				} else {
					let url = "http://localhost:9080/chat?route=" +
						encodeURIComponent(metadataText) +
						"&text=" +
						encodeURIComponent(newMessage.text)
					let request = $.NSMutableURLRequest.requestWithURL(
						$.NSURL.URLWithString(url)
					)
					request.setHTTPMethod("POST")
					$.NSURLSession.sharedSession.dataTaskWithRequest(request).
					resume
				}
			}
			pastLength = length
		}
	}

	return 2
}


function quit(){
	return true
}
                              [ jscr  ��ޭ