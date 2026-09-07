# Stretch

A single web page that opens an astronomy photo and brightens it so you can see
what is in it — and writes down everything it did.

Download one file. Double-click it. Drag your photo onto it. That is the whole
thing.

---

## Nothing you open here is uploaded

The page does not talk to the internet. Not to us, not to anyone.

**Don't take that on trust — it takes ten seconds to check:**

> **Turn off your Wi-Fi. Then use it.**
>
> It works exactly the same. A page that needed a server would stop.

If you want the stronger version: open your browser's developer tools (`F12`),
click the **Network** tab, and process a photo. The list stays empty.

There is no account, no sign-in, no upload button, and no analytics. There is
no server to send anything to — the file you downloaded *is* the program. You
can open it in a text editor and read it. That is not a figure of speech; it is
one file of readable code with no minification and no external libraries, and
the [repository](https://github.com/justyear/stretch) has the tests that prove
it does what it says.

---

## Using it

1. Download **`index.html`**.
2. Double-click it. It opens in your browser like any other page.
3. Drag a `.fit`, `.fits` or `.fz` file onto it.
4. Look at the result. Download the picture, and the log if you want it.

No installation. No Python, no dependencies, nothing to keep updated. It works
offline, on a laptop on a mountain, in Chrome or Firefox.

### If you have never heard of FITS

FITS is the file format telescopes and astronomy cameras write. It is not a
photo format — it is a table of measurements, one number per pixel, stored at
full precision and with the camera's settings recorded alongside.

Those numbers are almost always *very* dark. A real night sky is mostly black
with faint smudges, and if you open a FITS file in an ordinary photo viewer you
usually see a black rectangle. The picture is in there; it just needs to be
stretched so your eyes can reach it.

That is what this page does, and the reason it exists as a separate tool is
that stretching is where most software quietly starts making things up.

---

## What it does not do

The log every image comes with ends with a sentence like this one:

> Not applied: noise reduction, sharpening, saturation, deconvolution, star
> removal, colour grading, or any AI or generative step.

That sentence is generated, not typed. It is the list of everything the tool
knows how to name, minus whatever actually ran. If a step is ever added and it
runs, the sentence drops that word by itself. It cannot go stale, because
nobody maintains it.

**Nothing here invents detail.** No neural network, no upscaling, no
"enhancement". Every number in the log was measured from your file, and the log
says which.

What it *does* do, and says so:

- reads the FITS, including Rice-compressed `.fz`
- demosaics a colour-filter-array frame when there is one
- removes the light-pollution gradient, if it can measure one
- applies the standard autostretch (the PixInsight/Siril midtones transfer)
- writes an 8-bit PNG, and a log describing all of the above with numbers

---

## Checking it yourself

Everything below is optional. It is here because a tool that asks you to trust
it should hand you the means to stop trusting it.

```
powershell -File .claude\make-fixture.ps1        # build the test images
powershell -File .claude\serve.ps1 -Port 8791    # a local static server
```

Open `http://127.0.0.1:8791/test.html`, paste `test/capture-golden.js` into the
console, run `await __captureAll()`. Then:

| command | the question it answers |
|---|---|
| `test\compare-golden.ps1` | is today's output the same as yesterday's? |
| `test\compare-reference.ps1` | do the numbers agree with a separate implementation, written in Python, that shares none of this code? |
| `test\negative-controls.ps1` | can those checks still fail? (28 deliberate breakages, each of which must be caught) |
| `test\compare-truth.js` | is the fitted background the gradient we *put into* the test image — checked against numbers stored in the file's own header, which came from neither implementation? |
| `build\build.ps1 -Check` | is the published file exactly what this source builds? |

The test images are synthetic and generated from a fixed seed, so they are
reproducible and no one has to trust them either. **No frame from anyone else
is in this repository.**

`test/golden/MANIFEST.md` is the long version: what each test image covers, what
was measured, what is verified and what is not.

---

## Limits worth knowing

- **Very large frames depend on your browser's memory.** A stacked 4K frame in
  32-bit float is about 100 MB per channel, and the chain needs a few copies. If
  it runs out, it says so and tells you what to try.
- **`.fz` support covers `RICE_1`**, which is what Siril and `fpack` write by
  default. Other compressions are declined with an explanation.
- **The background extraction is automatic and has no manual override yet.** It
  shows you every sample it took and why it rejected the ones it rejected, but
  you cannot yet move them by hand. If it makes a bad call on your frame, that
  is a real limitation today.
- **It has been tested against synthetic frames and a second implementation, not
  against a large collection of real files.** The measurements are honest about
  which is which.

---

## Licence

MIT. Use it, change it, ship it, put it on your club's website. See `LICENSE`.

The licence is also in a comment at the top of `index.html`, because that file
travels alone — someone will email it to someone else, and at that point this
README is not there any more.
