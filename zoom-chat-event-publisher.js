ObjC.import("Foundation")
ObjC.import("Cocoa")

let currApp = Application.currentApplication()
currApp.includeStandardAdditions = true

let SE = Application("System Events")
SE.includeStandardAdditions = true

let requestQueue = []
let metadataText = ""
let pastLength = 0
let promptDisplayed = false
let dormant = false
let ZoomApp = SE.applicationProcesses.byName("zoom.us")

function makeAllRequests() {
	if (requestQueue.length) {
		let url = requestQueue[0]
		let request = $.NSMutableURLRequest.requestWithURL(
			$.NSURL.URLWithString(url)
		)
		request.setHTTPMethod("POST")
		$.NSURLSession.sharedSession.dataTaskWithRequestCompletionHandler(
			request,
			(data, resp) => {
				let statusCode = resp.statusCode
				if (statusCode && statusCode < 300) {
					requestQueue.shift()
					makeAllRequests()
				}
			}
		).
		resume
	}
}

function isMeetingOngoing() {
	// the window "Zoom meeting" isn't reported if it's in a non-active Mission Control "Space"
	// so let's check whether Zoom's Window menu contains a "Zoom Meeting" menuItem
	try {
		let winMenuItems = ZoomApp.menuBars()[0].menuBarItems.byName("Window").menus.byName("Window").menuItems()
		for (let i = 0; i < winMenuItems.length; i++) {
			const name = winMenuItems[i]().name()
			if (name != null && name.startsWith("Zoom Meeting")) {
				return true;
			}
		}
	} catch (error) {
		// No-op - this just means we are unable to find the menu, which can happen when there is no meeting
	}
	return ZoomApp.windows.whose({ name: { _contains: "Meeting Chat" } }).length === 1
}

function getChatMessages() {
	// returns the number of lines in chat (including the name lines!)
	let messages = []
	let table

	// get content of detached chat window - use Xcode Accessibility Inspector
	let chatWin = ZoomApp.windows.whose({ name: { _contains: "Meeting Chat" } })
	if (chatWin.length == 1) {
		// there is a chat window
		table = chatWin.splitterGroups[0].groups[0].scrollAreas[0].tables[0]
	} else {
		// get content of attached chat window
		let meetWin = ZoomApp.windows.whose({ name: { _contains: "Zoom Meeting" } })

		let chatEmbedded = meetWin.splitterGroups[0]
		if (chatEmbedded()[0] == null) {
			// the chat panel is not where it should
			return null
		}

		table = chatEmbedded.groups[0].scrollAreas[0].tables[0]
	}
	let textRows = table.rows
	let curLength = textRows.length
	try {
		for (let i = Math.max(pastLength, curLength - 50); i < curLength; i ++) {
			let chatRow = textRows[i].uiElements[0]
			let textIndex = 0
			if (chatRow.uiElements.length > 1 && chatRow.uiElements.length != 4) {
				textIndex = 2
				messages.push(
					{
						metadata: true,
						text: chatRow.uiElements[0].value()[0]
					}
				)
			}
			messages.push(
				{
					metadata: false,
					text: chatRow.uiElements[textIndex].value()[0]
				}
			)
		}
	} catch (error) {
		return null
	}
	pastLength = curLength

	return messages
}


function idle() {
	let messages
	if (!isMeetingOngoing()) {
		if (!dormant) {
			// let's warn and go dormant
			metadataText = ""
			pastLength = 0
			promptDisplayed = false
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
		if (!promptDisplayed) {
			currApp.displayNotification("Please open it to detect changes",
				{withTitle:"The chat window seems to be closed!"})
			promptDisplayed = true
		}
			
		return 3
	} else  {
		promptDisplayed = false
		for (let i = 0, len = messages.length; i < len; ++i) {
			let message = messages[i]
			if (message.metadata) {
				metadataText = message.text
			} else {
				let url = "http://localhost:8973/chat?route=" +
					encodeURIComponent(metadataText) +
					"&text=" +
					encodeURIComponent(message.text)
				requestQueue.push(url)
			}
		}
		makeAllRequests()
	}

	return 1
}

function quit() {
	return true
}

function run() {
        delay(idle())
        run()
}

run()
