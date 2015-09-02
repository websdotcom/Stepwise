# Stepwise

**NOTE:** For Swift 2 support, try the Stepwise 2.0 beta using the `2.0-beta2` tag in Cocoapods or the [swift-2.0](https://github.com/websdotcom/Stepwise/tree/swift-2.0) branch.

Stepwise is a Swift framework for executing a series of steps asynchronously. Steps are single-dependency and cancelable. `Step` objects wrap your closures; they're genericized so you get strongly-typed inputs and outputs. Here's a totally contrived example of steps to fetch an image from the Internet and shrink it by half:

```swift
let fetchAndResizeImageSteps = toStep { (step: Step<NSURL, UIImage>) in
    // This is the url we pass into the step chain
    let url = step.input
    
    // Fetch the image data. Obviously we'd be using Alamofire or something irl.
    if let imageData = NSData(contentsOfURL: url) {
        // Create the image
        let image = UIImage(data: imageData)!
        
        // Pass it to the next step
        step.resolve(image)
    }
    else {
        // Oh no! Something went wrong!
        step.error(NSError(domain: "com.my.domain", code: -1, userInfo: nil))
    }
}.then { (step: Step<UIImage, UIImage>) in
    // Grab the fetched image
    let image = step.input
    
    // Resize it
    let targetSize = CGSize(width: image.size.width / 2.0, height: image.size.height / 2.0)
    UIGraphicsBeginImageContextWithOptions(targetSize, true, 0.0)
    image.drawInRect(CGRect(origin: CGPoint(x: 0, y: 0), size: targetSize))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    // Return it
    step.resolve(resizedImage)
}.then { (step: Step<UIImage, Void>) in
    // Get fetched, resized image
    let image = step.input
    
    // Do something with image here.
    // Set it to a shared variable, pass it to another step, etc.
    step.resolve()
}

// Having set up the chain of steps, pass in a URL to get fetching.
let importantImageURL = NSURL(string: "http://i1.kym-cdn.com/entries/icons/original/000/000/774/lime-cat.jpg")!
fetchAndResizeImageSteps.start(importantImageURL)
```

The first step, created by the `toStep` function, accepts a closure with a single step parameter. The step parameter is of type `Step<NSURL, UIImage>`, so it accepts an `NSURL` as input and outputs a `UIImage` if successful. The first step fetches the data from the URL and tries to create an image from it. If it fails the step results in an error and calls `step.error()`. If all is well the step resolves by calling `step.resolve(image)`.

When a step resolves successfully it passes its output as input to the next step, which is created by calling `then()`. In this example the second step resizes the image to half-size, then resolves with it. There is no error case.

The third step, also enqueued with `then()`, is just an example of a step with a `Void` output. Steps with `Void` outputs may call `resolve()` without an argument, just as steps with `Void` inputs may call `start()` without an argument.

### Errors

In the example above there is no error handler for the `error()` in the first step, but a handler can be added at any point in the chain by calling `onError()`. `onError()` accepts a simple closure with an `NSError` parameter and allows your code to react to errors generated by steps. Here's a quick example:

```swift
// prints "ERROR: Error in step 1!"
toStep { (step: Step<Void, String>) in
    step.error(NSError(domain: "com.my.domain", code: -1, userInfo: [NSLocalizedDescriptionKey : "Error in step 1!"]))
}.then { (step : Step<String, Int>) in
    // This never executes.
    println("I never execute!")
    step.resolve(countElements(step.input))
}.onError { error in
    println("ERROR: \(error.localizedDescription)")
}.start()
```

An important limitation to note is that, at present, a chain of steps can only have a single error handler. You can multiplex responses to errors in the handler by erroring with different domains, codes, or userInfos per step.

### Cancellation

Cancellation is baked right into Stepwise. Every step chain has a `cancellationToken` property that returns a `CancellationToken` object. This object provides a single method, `cancel()`, which cancels any step that has this token. Every step in a chain will consult the token before and during execution to see if it has been canceled. Here's an example:

```swift
let willCancelStep = toStep { (step: Step<Void, String>) in
    // Will never execute.
    step.resolve("some result")
}

willCancelStep.start()

// Grab the step's token and cancel it.
let token = willCancelStep.cancellationToken
token.cancel(reason: "Canceling for a really good reason.")
```

You may optionally provide a `String` reason in the cancel method for logging purposes.

### Finally

Each chain also provides a `finally` method which you can call to attach a handler that will *always* execute when the chain ends, errors, or is canceled. A parameter of type `ChainState` is passed into the handler to indicate the result of the chain. Relying on `finally` to process the result of a chain is discouraged; instead, use another `then` step with a `Void` output type. `finally` is provided for must-occur situations regardless of error or cancel state, like closing file resources. Here's an example:

```swift
// In this extremely contrived example, assume we already have an open `NSOutputStream`
// that we must close after our steps complete, regardless of success or erroring out.
let outputStream : NSOutputStream = ...
let someDataURL : NSURL = ...

toStep { (step : Step<Void, NSData>) in
    if let someData = NSData(contentsOfURL: someDataURL) {
        step.resolve(someData)
    }
    else {
        step.error(NSError(domain: "com.my.domain.fetch-data", code: -1, userInfo: nil))
    }
}.then { (step: Step<NSData, Void>) in
    // Write our data
    let data = step.input
    var bytes = UnsafePointer<UInt8>(data.bytes)
    var bytesRemaining = data.length

    while bytesRemaining > 0 {
        let written = outputStream.write(bytes, maxLength: bytesRemaining)
        if written == -1 {
            step.error(NSError(domain: "com.my.domain.write-data", code: -1, userInfo: nil))
            return
        }

        bytesRemaining -= written
        bytes += written
    }

    step.resolve()
}.onError { error in
    // Handle error here...
}.finally { resultState in
    // Close the stream here
    outputStream.close()
}.start()
```

### Tests

All of the examples in this README and others can be found in the library's tests, in [StepwiseTests.swift](https://github.com/websdotcom/Stepwise/blob/master/StepwiseTests/StepwiseTests.swift).

### Random Goodies

Stepwise is lovingly crafted by and used in [Pagemodo.app](https://itunes.apple.com/us/app/pagemodo-for-social-media/id937853905?mt=8). Check it out if you want to make posting to social networks not terrible.

Set `Stepwise.StepDebugLoggingEnabled` to `true` to get log messages of what's happening in your steps.

### Swift Versions

Stepwise uses Swift 1.2. The following table tracks older Swift versions and the corresponding git tag to use for that version.

Swift Version | Tag
------------- | ---
1.0 | swift-1.1
1.1 | swift-1.1


### License

    Copyright (c) 2014, Webs <kevin@webs.com>

    Permission to use, copy, modify, and/or distribute this software for any
    purpose with or without fee is hereby granted, provided that the above
    copyright notice and this permission notice appear in all copies.

    THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
    WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
    MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
    ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
    WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
    ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
    OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.