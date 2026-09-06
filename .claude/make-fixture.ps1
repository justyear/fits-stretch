# Builds the synthetic FITS fixtures the tests run against.
#
#   .\make-fixture.ps1              all three
#   .\make-fixture.ps1 -Only rice   just one
#
# Everything here is generated from a fixed seed, so the fixtures are
# reproducible byte for byte and the goldens stay valid without the files
# having to be trusted. No frame from anyone else ever enters this tree; see
# CLAUDE.md.
#
#   fixture-seestar.fit     1920 x 1080, BITPIX 16 + BZERO 32768, BAYERPAT
#                           GRBG, ROWORDER BOTTOM-UP, big-endian. Stars of
#                           KNOWN colour: if red and blue swap, the red star
#                           comes out blue and the failure is visible instead
#                           of statistical. Covers int16, the row flip, CFA
#                           detection, debayer, the linear stretch.
#
#   fixture-rice.fit.fz     2600 x 1000 x 3, BITPIX -32, RICE_1 with
#                           SUBTRACTIVE_DITHER_2, one tile per row. Covers
#                           tile decompression, the dither, the 3-plane path
#                           (no debayer), and view.factor 2 — the long edge is
#                           deliberately just past MAX_VIEW (2560).
#
#   fixture-nonlinear.fit   900 x 600 x 3, BITPIX -32, ROWORDER TOP-DOWN, with
#                           HISTORY cards recording an autostretch and a
#                           median around 0.25. Covers the non-linear branch:
#                           black point by percentile, target at the channel's
#                           own median.
#
#   fixture-gradient.fit    1600 x 1200 x 3, BITPIX -32, ROWORDER TOP-DOWN.
#                           A background gradient whose coefficients are in the
#                           HISTORY cards, an extended object over 12% of the
#                           frame, probe stars at recorded positions, Gaussian
#                           noise. For Module 1: sample rejection, and the only
#                           check in this suite that can answer "is the fitted
#                           model the gradient I put in?" rather than "is the
#                           model the same as yesterday?".
#
# Not part of the deliverable — test fixtures only.

param([ValidateSet('all', 'seestar', 'rice', 'nonlinear', 'gradient')][string]$Only = 'all')

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'test\fixtures'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;

public static class FitsFixture
{
    // Deterministic, so the fixture is reproducible byte for byte.
    public class Lcg {
        ulong s;
        public Lcg(ulong seed){ s = seed; }
        public double Next(){ s = s * 6364136223846793005UL + 1442695040888963407UL;
                              return ((s >> 11) & 0x1FFFFFFFFFFFFFUL) / 9007199254740992.0; }

        // Box-Muller. The other fixtures use uniform noise, which is fine when
        // nothing reads the shape of the distribution. The gradient fixture is
        // different: sample rejection is `box median > global median +
        // tolerance * MADN`, and MADN only means "sigma" for Gaussian noise.
        // Uniform noise would put the rejection threshold somewhere that has no
        // interpretation, and the fixture would be testing the wrong thing.
        public double Gauss(){
            double u1 = Next(); if (u1 < 1e-12) u1 = 1e-12;
            double u2 = Next();
            return Math.Sqrt(-2.0 * Math.Log(u1)) * Math.Cos(2.0 * Math.PI * u2);
        }
    }

    struct Star { public double X, Y, Sigma, R, G, B; }

    public static byte[] Build(int W, int H)
    {
        var rnd = new Lcg(20260901);
        var r = new float[W * H];
        var g = new float[W * H];
        var b = new float[W * H];

        // Background: gentle gradient with a warm light-pollution cast.
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                double bg = 600.0 + 140.0 * ((double)x / W) + 90.0 * ((double)y / H);
                int i = y * W + x;
                r[i] = (float)(bg * 1.12);
                g[i] = (float)(bg);
                b[i] = (float)(bg * 0.90);
            }

        var stars = new System.Collections.Generic.List<Star>();

        // Known-colour probes, on the top half of the IMAGE.
        stars.Add(new Star { X = 400,  Y = 300, Sigma = 3.2, R = 20000, G = 1100, B = 800  });  // red
        stars.Add(new Star { X = 700,  Y = 300, Sigma = 3.2, R = 900,  G = 20000, B = 800  });  // green
        stars.Add(new Star { X = 1000, Y = 300, Sigma = 3.2, R = 800,  G = 1100, B = 20000 });  // blue
        stars.Add(new Star { X = 1400, Y = 300, Sigma = 5.0, R = 17000, G = 17000, B = 17000 }); // white

        // A field of ordinary stars so the statistics look like a real frame.
        for (int k = 0; k < 260; k++)
        {
            double amp = 400 + 9000 * Math.Pow(rnd.Next(), 3.0);
            double tint = 0.75 + 0.5 * rnd.Next();
            stars.Add(new Star {
                X = rnd.Next() * W, Y = rnd.Next() * H,
                Sigma = 1.5 + 1.8 * rnd.Next(),
                R = amp * tint, G = amp, B = amp / tint
            });
        }

        foreach (var s in stars)
        {
            int rad = (int)Math.Ceiling(s.Sigma * 4);
            int x0 = Math.Max(0, (int)s.X - rad), x1 = Math.Min(W - 1, (int)s.X + rad);
            int y0 = Math.Max(0, (int)s.Y - rad), y1 = Math.Min(H - 1, (int)s.Y + rad);
            double twoSigmaSq = 2.0 * s.Sigma * s.Sigma;
            for (int y = y0; y <= y1; y++)
                for (int x = x0; x <= x1; x++)
                {
                    double dx = x - s.X, dy = y - s.Y;
                    double f = Math.Exp(-(dx * dx + dy * dy) / twoSigmaSq);
                    int i = y * W + x;
                    r[i] += (float)(s.R * f);
                    g[i] += (float)(s.G * f);
                    b[i] += (float)(s.B * f);
                }
        }

        // GRBG at the top-left of the IMAGE:  row 0 = G R G R,  row 1 = B G B G
        // Data is written bottom-up, so stored row j is image row H-1-j.
        var data = new byte[W * H * 2];
        int p = 0;
        for (int j = 0; j < H; j++)
        {
            int y = H - 1 - j;
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x;
                double v;
                if ((y & 1) == 0) v = ((x & 1) == 0) ? g[i] : r[i];
                else              v = ((x & 1) == 0) ? b[i] : g[i];

                v += (rnd.Next() - 0.5) * 60.0;                 // read noise
                if (v < 0) v = 0; else if (v > 65535) v = 65535;

                int raw = (int)Math.Round(v) - 32768;           // physical = BZERO + raw
                short s16 = (short)raw;
                data[p++] = (byte)((s16 >> 8) & 0xFF);          // big-endian
                data[p++] = (byte)(s16 & 0xFF);
            }
        }
        return data;
    }

    /* ---------------------------------------------------------------- *
     * A linear RGB scene in [0,1], planar, used by both float fixtures.
     * ---------------------------------------------------------------- */
    public static float[] Scene(int W, int H, int planes, ulong seed,
                                double floorLevel, double noise, double gradient)
    {
        var rnd = new Lcg(seed);
        int N = W * H;
        var img = new float[N * planes];
        double[] tint = { 1.10, 1.00, 0.92 };

        for (int c = 0; c < planes; c++)
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    double bg = floorLevel * (1.0 + gradient * ((double)x / W)
                                                  + gradient * 0.6 * ((double)y / H));
                    img[c * N + y * W + x] = (float)(bg * tint[c % 3]);
                }

        int nstars = (int)(N / 2600.0) + 40;
        for (int k = 0; k < nstars; k++)
        {
            double amp   = 0.004 + 0.9 * Math.Pow(rnd.Next(), 3.2);
            double sigma = 1.4 + 2.2 * rnd.Next();
            double sx = rnd.Next() * W, sy = rnd.Next() * H;
            double shade = 0.75 + 0.5 * rnd.Next();
            double[] amps = { amp * shade, amp, amp / shade };

            int rad = (int)Math.Ceiling(sigma * 4);
            int x0 = Math.Max(0, (int)sx - rad), x1 = Math.Min(W - 1, (int)sx + rad);
            int y0 = Math.Max(0, (int)sy - rad), y1 = Math.Min(H - 1, (int)sy + rad);
            double twoSigmaSq = 2.0 * sigma * sigma;

            for (int c = 0; c < planes; c++)
                for (int y = y0; y <= y1; y++)
                    for (int x = x0; x <= x1; x++)
                    {
                        double dx = x - sx, dy = y - sy;
                        double f = Math.Exp(-(dx * dx + dy * dy) / twoSigmaSq);
                        img[c * N + y * W + x] += (float)(amps[c % 3] * f);
                    }
        }

        for (int i = 0; i < img.Length; i++)
        {
            double v = img[i] + (rnd.Next() - 0.5) * 2.0 * noise;
            if (v > 1.0) v = 1.0;
            img[i] = (float)v;
        }
        return img;
    }

    /* ---------------------------------------------------------------- *
     * The gradient fixture — the only one in this suite whose background is
     * known independently of both implementations.
     *
     * Everything the caller passes in is also written into HISTORY cards by
     * the caller, from the same variables. That is the whole point: the test
     * compares the fitted background model against these numbers, which came
     * out of neither the JavaScript nor the Python. It is what breaks the
     * limitation recorded in section 5 of modulo-1-spec.md and section 7 of
     * modulo-0-spec.md — that both implementations share the formula, so a
     * wrong formula is invisible to both.
     *
     * Build order matters and is fixed: gradient, then object, then probe
     * stars, then field stars, then noise. The noise is last so that nothing
     * downstream is a smooth function of it.
     * ---------------------------------------------------------------- */
    public static float[] GradientScene(
        int W, int H, ulong seed,
        double[] coefR, double[] coefG, double[] coefB,   // A0..A5 each
        double noiseSigma,
        double[] obj,          // cx, cy, a, b, peak, k
        double[] objTint,      // per-channel scale for the object
        double[] probes,       // x0,y0,x1,y1,... flattened
        double probeAmp, double probeSigma,
        int nField, ulong fieldSeed)
    {
        int N = W * H;
        var img = new float[N * 3];
        var coef = new double[][] { coefR, coefG, coefB };

        // 1. The gradient, evaluated exactly as the HISTORY cards state it.
        //    u and v are normalised on (NAXIS-1) so that u=1 lands on the last
        //    column rather than one past it. Off-by-one here would make the
        //    truth wrong by a fraction of a pixel everywhere, which is the kind
        //    of error a test compares against itself and never sees.
        for (int c = 0; c < 3; c++)
        {
            var k = coef[c];
            for (int y = 0; y < H; y++)
            {
                double v = (double)y / (H - 1);
                for (int x = 0; x < W; x++)
                {
                    double u = (double)x / (W - 1);
                    img[c * N + y * W + x] =
                        (float)(k[0] + k[1] * u + k[2] * v + k[3] * u * u + k[4] * v * v + k[5] * u * v);
                }
            }
        }

        // 2. The extended object. Exponential in elliptical radius, so it has
        //    a bright core that any sane rejection catches and faint outskirts
        //    that blend into the background — which is the case that matters.
        //    An object with a hard edge would make rejection look easy.
        double cx = obj[0], cy = obj[1], oa = obj[2], ob = obj[3], peak = obj[4], kk = obj[5];
        int bx0 = Math.Max(0, (int)(cx - 3.0 * oa)), bx1 = Math.Min(W - 1, (int)(cx + 3.0 * oa));
        int by0 = Math.Max(0, (int)(cy - 3.0 * ob)), by1 = Math.Min(H - 1, (int)(cy + 3.0 * ob));
        for (int y = by0; y <= by1; y++)
            for (int x = bx0; x <= bx1; x++)
            {
                double dx = (x - cx) / oa, dy = (y - cy) / ob;
                double R = Math.Sqrt(dx * dx + dy * dy);
                double I = peak * Math.Exp(-kk * R);
                for (int c = 0; c < 3; c++) img[c * N + y * W + x] += (float)(I * objTint[c]);
            }

        // 3. Probe stars, at positions the header records.
        //
        //    Sigma is small on purpose. A 25-pixel sample box holds 625 pixels;
        //    a Gaussian of sigma 2.2 puts roughly 140 of them meaningfully
        //    above background, which is 22% — comfortably under half. So the
        //    box MEDIAN survives the star and the box MEAN does not, which is
        //    exactly the property section 2.1 of the spec asks for and exactly
        //    what this fixture exists to check. A larger sigma would flip the
        //    median too and the fixture would be arguing the opposite case.
        for (int s = 0; s + 1 < probes.Length; s += 2)
            AddStar(img, W, H, probes[s], probes[s + 1], probeSigma,
                    probeAmp, probeAmp, probeAmp);

        // 4. Ordinary field stars, so the frame's statistics look like a frame.
        //    Not part of the truth: the box median is meant to reject them too.
        var rnd = new Lcg(fieldSeed);
        for (int k2 = 0; k2 < nField; k2++)
        {
            double amp = 0.006 + 0.35 * Math.Pow(rnd.Next(), 3.0);
            double sig = 1.3 + 1.4 * rnd.Next();
            double sx = rnd.Next() * W, sy = rnd.Next() * H;
            double shade = 0.80 + 0.40 * rnd.Next();
            AddStar(img, W, H, sx, sy, sig, amp * shade, amp, amp / shade);
        }

        // 5. Noise, last.
        var nrnd = new Lcg(seed);
        for (int i = 0; i < img.Length; i++)
        {
            double val = img[i] + nrnd.Gauss() * noiseSigma;
            if (val < 0) val = 0; else if (val > 1) val = 1;
            img[i] = (float)val;
        }
        return img;
    }

    static void AddStar(float[] img, int W, int H, double sx, double sy,
                        double sigma, double ar, double ag, double ab)
    {
        int N = W * H;
        double[] amps = { ar, ag, ab };
        int rad = (int)Math.Ceiling(sigma * 4);
        int x0 = Math.Max(0, (int)sx - rad), x1 = Math.Min(W - 1, (int)sx + rad);
        int y0 = Math.Max(0, (int)sy - rad), y1 = Math.Min(H - 1, (int)sy + rad);
        double twoSigmaSq = 2.0 * sigma * sigma;
        for (int c = 0; c < 3; c++)
            for (int y = y0; y <= y1; y++)
                for (int x = x0; x <= x1; x++)
                {
                    double dx = x - sx, dy = y - sy;
                    double f = Math.Exp(-(dx * dx + dy * dy) / twoSigmaSq);
                    img[c * N + y * W + x] += (float)(amps[c] * f);
                }
    }

    // The same midtones transfer the tool applies, used here to make the
    // non-linear fixture genuinely non-linear instead of a linear frame with a
    // false HISTORY card.
    public static void Mtf(float[] img, double m)
    {
        for (int i = 0; i < img.Length; i++)
        {
            double x = img[i];
            if (x <= 0){ img[i] = 0f; continue; }
            if (x >= 1){ img[i] = 1f; continue; }
            img[i] = (float)(((m - 1.0) * x) / (((2.0 * m - 1.0) * x) - m));
        }
    }

    // Big-endian float32, planar, optionally row-flipped.
    public static byte[] FloatBytes(float[] img, int W, int H, int planes, bool bottomUp)
    {
        var outb = new byte[img.Length * 4];
        int p = 0, N = W * H;
        for (int c = 0; c < planes; c++)
            for (int j = 0; j < H; j++)
            {
                int y = bottomUp ? (H - 1 - j) : j;
                for (int x = 0; x < W; x++)
                {
                    var bs = BitConverter.GetBytes(img[c * N + y * W + x]);
                    outb[p++] = bs[3]; outb[p++] = bs[2]; outb[p++] = bs[1]; outb[p++] = bs[0];
                }
            }
        return outb;
    }
}

/* -------------------------------------------------------------------- *
 * Rice encoder — the exact inverse of riceDecompress in
 * src/pipeline/fits/rice.js, for BYTEPIX 4 (fsbits 5, fsmax 25, 32-bit).
 * Bits go out MSB-first, which is the order the decoder reads them.
 * -------------------------------------------------------------------- */
public class BitWriter
{
    byte[] buf; int len; ulong acc; int nb;
    public BitWriter(int cap){ buf = new byte[cap < 64 ? 64 : cap]; }
    public int Length { get { return len; } }

    void Emit(byte b){
        if (len == buf.Length) Array.Resize(ref buf, buf.Length * 2);
        buf[len++] = b;
    }
    public void Put(uint v, int count){
        if (count == 0) return;
        uint masked = (count >= 32) ? v : (v & ((1u << count) - 1u));
        acc = (acc << count) | masked;
        nb += count;
        while (nb >= 8){ nb -= 8; Emit((byte)(acc >> nb)); }
        acc &= (nb == 0) ? 0UL : ((1UL << nb) - 1UL);
    }
    public void PutZeros(long n){
        while (n > 0){ int c = (int)Math.Min(n, 24); Put(0u, c); n -= c; }
    }
    public byte[] Finish(){
        if (nb > 0) Put(0u, 8 - nb);            // pad the last byte with zeros
        var outb = new byte[len];
        Array.Copy(buf, outb, len);
        return outb;
    }
}

public static class Rice
{
    const int FSBITS = 5, FSMAX = 25, BBITS = 32;

    public static byte[] Compress(int[] vals, int n, int nblock)
    {
        var bw = new BitWriter(n * 4 + 64);
        int lastpix = vals[0];

        // The decoder primes lastpix from these bytepix bytes, then still
        // decodes all n values, so the first difference is zero.
        bw.Put((uint)((lastpix >> 24) & 0xFF), 8);
        bw.Put((uint)((lastpix >> 16) & 0xFF), 8);
        bw.Put((uint)((lastpix >> 8)  & 0xFF), 8);
        bw.Put((uint)(lastpix & 0xFF), 8);

        var diffs = new uint[nblock];
        int i = 0;
        while (i < n)
        {
            int imax = Math.Min(i + nblock, n);
            int count = imax - i;

            int lp = lastpix;
            bool allZero = true;
            for (int k = 0; k < count; k++)
            {
                int d = unchecked(vals[i + k] - lp);
                lp = vals[i + k];
                uint z = unchecked((uint)((d < 0) ? ~(d << 1) : (d << 1)));
                diffs[k] = z;
                if (z != 0) allZero = false;
            }

            if (allZero)
            {
                bw.Put(0u, FSBITS);              // fs = -1: block repeats lastpix
                i = imax;
                continue;
            }

            long fsmaxBits = (long)count * BBITS;
            long best = long.MaxValue;
            int bestFs = FSMAX;
            for (int fs = 0; fs < FSMAX; fs++)
            {
                long bits = 0;
                bool over = false;
                for (int k = 0; k < count; k++)
                {
                    bits += (long)(diffs[k] >> fs) + 1 + fs;
                    if (bits >= fsmaxBits){ over = true; break; }
                }
                if (!over && bits < best){ best = bits; bestFs = fs; }
            }

            bw.Put((uint)(bestFs + 1), FSBITS);
            if (bestFs == FSMAX)
            {
                for (int k = 0; k < count; k++) bw.Put(diffs[k], 32);
            }
            else
            {
                for (int k = 0; k < count; k++)
                {
                    uint d = diffs[k];
                    bw.PutZeros((long)(d >> bestFs));
                    bw.Put(1u, 1);
                    if (bestFs > 0) bw.Put(d & ((1u << bestFs) - 1u), bestFs);
                }
            }

            lastpix = lp;
            i = imax;
        }
        return bw.Finish();
    }
}

public class FzResult
{
    public byte[] Data;      // table rows followed by the heap
    public int HeapLen;
    public int MaxElem;
    public int Rows;
}

public static class FzWriter
{
    const int N_RANDOM = 10000;
    const int DITHER_ZERO = -2147483647;

    // cfitsio's Park-Miller table, generated exactly as initRandoms() does.
    static double[] Randoms()
    {
        double a = 16807.0, m = 2147483647.0, seed = 1.0;
        var r = new double[N_RANDOM];
        for (int i = 0; i < N_RANDOM; i++)
        {
            double temp = a * seed;
            seed = temp - m * Math.Floor(temp / m);
            r[i] = seed / m;
        }
        return r;
    }

    // One tile per image row, per plane — cfitsio's default tiling.
    public static FzResult Build(float[] img, int W, int H, int planes,
                                 double zscale, double zzero, int dither0,
                                 int blocksize, bool bottomUp)
    {
        var rnd = Randoms();
        int rows = H * planes;
        int rowBytes = 24;                       // 1PB descriptor + 2 doubles

        var table = new byte[rows * rowBytes];
        var heap = new MemoryStream();
        var idata = new int[W];
        int maxElem = 0;
        int N = W * H;

        for (int t = 0; t < rows; t++)
        {
            int plane = t / H, j = t % H;
            int y = bottomUp ? (H - 1 - j) : j;
            int src = plane * N + y * W;

            // Dither state, mirrored from decodeTileCompressed.
            int iseed = (t + dither0 - 1) % N_RANDOM;
            if (iseed < 0) iseed += N_RANDOM;
            int nextrand = (int)(rnd[iseed] * 500);

            for (int x = 0; x < W; x++)
            {
                double v = img[src + x];
                if (v == 0.0)
                {
                    idata[x] = DITHER_ZERO;      // SUBTRACTIVE_DITHER_2 sentinel
                }
                else
                {
                    double q = (v - zzero) / zscale + rnd[nextrand] - 0.5;
                    idata[x] = (int)Math.Round(q, MidpointRounding.AwayFromZero);
                }
                nextrand++;
                if (nextrand == N_RANDOM)
                {
                    iseed++;
                    if (iseed == N_RANDOM) iseed = 0;
                    nextrand = (int)(rnd[iseed] * 500);
                }
            }

            var packed = Rice.Compress(idata, W, blocksize);
            int hoff = (int)heap.Position;
            heap.Write(packed, 0, packed.Length);
            if (packed.Length > maxElem) maxElem = packed.Length;

            int o = t * rowBytes;
            PutInt32BE(table, o,     packed.Length);
            PutInt32BE(table, o + 4, hoff);
            PutDoubleBE(table, o + 8,  zscale);
            PutDoubleBE(table, o + 16, zzero);
        }

        var heapBytes = heap.ToArray();
        var data = new byte[table.Length + heapBytes.Length];
        Array.Copy(table, 0, data, 0, table.Length);
        Array.Copy(heapBytes, 0, data, table.Length, heapBytes.Length);

        return new FzResult { Data = data, HeapLen = heapBytes.Length,
                              MaxElem = maxElem, Rows = rows };
    }

    static void PutInt32BE(byte[] b, int o, int v)
    {
        b[o] = (byte)(v >> 24); b[o+1] = (byte)(v >> 16);
        b[o+2] = (byte)(v >> 8); b[o+3] = (byte)v;
    }
    static void PutDoubleBE(byte[] b, int o, double v)
    {
        var s = BitConverter.GetBytes(v);
        for (int i = 0; i < 8; i++) b[o + i] = s[7 - i];
    }
}
'@

function New-Card([string]$Key, $Value, [string]$Comment, [switch]$AsString) {
    $k = $Key.PadRight(8).Substring(0, 8)
    if ($AsString) {
        $body = ("'" + ([string]$Value).PadRight(8) + "'").PadRight(20)
    } else {
        $body = ([string]$Value).PadLeft(20)
    }
    $card = "$k= $body"
    if ($Comment) { $card = "$card / $Comment" }
    if ($card.Length -gt 80) { $card = $card.Substring(0, 80) }
    return $card.PadRight(80)
}

function Write-Fits([string]$Path, [string[]]$Cards, [byte[]]$Data) {
    $headerText = (($Cards + ('END'.PadRight(80))) -join '')
    $pad = (2880 - ($headerText.Length % 2880)) % 2880
    $headerText = $headerText + (' ' * $pad)
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerText)

    $tail = (2880 - ($Data.Length % 2880)) % 2880
    $fs = [System.IO.File]::Create($Path)
    try {
        $fs.Write($headerBytes, 0, $headerBytes.Length)
        $fs.Write($Data, 0, $Data.Length)
        if ($tail -gt 0) { $fs.Write((New-Object byte[] $tail), 0, $tail) }
    } finally { $fs.Close() }
    Write-Host ("  wrote {0} - {1:N0} bytes" -f $Path, (Get-Item $Path).Length)
}

# ---------------------------------------------------------------- seestar
if ($Only -eq 'all' -or $Only -eq 'seestar') {
    $W = 1920; $H = 1080
    Write-Host "fixture-seestar.fit  ($W x $H, int16, CFA GRBG)"
    $cards = @(
        (New-Card 'SIMPLE'   'T'   'conforms to FITS standard')
        (New-Card 'BITPIX'   16    'unsigned 16-bit via BZERO')
        (New-Card 'NAXIS'    2)
        (New-Card 'NAXIS1'   $W)
        (New-Card 'NAXIS2'   $H)
        (New-Card 'BZERO'    32768 'offset for unsigned data')
        (New-Card 'BSCALE'   1)
        (New-Card 'BAYERPAT' 'GRBG' 'CFA at image top-left' -AsString)
        (New-Card 'ROWORDER' 'BOTTOM-UP' 'first row is image bottom' -AsString)
        (New-Card 'XBAYROFF' 0)
        (New-Card 'YBAYROFF' 0)
        (New-Card 'INSTRUME' 'Synthetic' 'not a real camera' -AsString)
        (New-Card 'PROGRAM'  'make-fixture.ps1' '' -AsString)
        (New-Card 'OBJECT'   'CFA probe' 'known-colour stars' -AsString)
        (New-Card 'EXPTIME'  '10.' 'seconds')
    )
    Write-Fits (Join-Path $outDir 'fixture-seestar.fit') $cards ([FitsFixture]::Build($W, $H))
}

# ------------------------------------------------------------------- rice
if ($Only -eq 'all' -or $Only -eq 'rice') {
    # 2600 is deliberately just past MAX_VIEW (2560), so downscale() picks
    # factor 2 and the PNG comes from the full-resolution buffer rather than
    # the display copy — the path the download button actually takes.
    $W = 2600; $H = 1000; $planes = 3
    $blocksize = 32
    $dither0 = 2625

    # The quantisation is set up so the stored integers sit just above the
    # int32 floor, the way a real fpack'd frame does: ZZERO is six orders of
    # magnitude larger than the value it reconstructs. That is what forces the
    # unquantize to stay in double, and this fixture is what would catch it if
    # someone ever routes it through a Float32Array.
    $zscale = 6.2e-6
    $floor  = 0.012
    $zzero  = $floor + 2147400000.0 * $zscale

    Write-Host "fixture-rice.fit.fz  ($W x $H x $planes, RICE_1, dither 2)"
    Write-Host ("  zscale {0:E4}  zzero {1:F4}" -f $zscale, $zzero)

    $img = [FitsFixture]::Scene($W, $H, $planes, 20260905, $floor, 0.00045, 0.35)

    # A patch of exact zeros, so the SUBTRACTIVE_DITHER_2 "was exactly 0.0"
    # sentinel is exercised rather than merely implemented.
    for ($c = 0; $c -lt $planes; $c++) {
        for ($y = 120; $y -lt 144; $y++) {
            $base = $c * $W * $H + $y * $W
            for ($x = 200; $x -lt 224; $x++) { $img[$base + $x] = 0.0 }
        }
    }

    $fz = [FzWriter]::Build($img, $W, $H, $planes, $zscale, $zzero, $dither0, $blocksize, $true)
    Write-Host ("  {0:N0} tiles, heap {1:N0} bytes, largest tile {2:N0} bytes" -f $fz.Rows, $fz.HeapLen, $fz.MaxElem)

    $cards = @(
        (New-Card 'SIMPLE'   'T'  'conforms to FITS standard')
        (New-Card 'BITPIX'   8)
        (New-Card 'NAXIS'    0)
        (New-Card 'EXTEND'   'T')
    )
    Write-Fits (Join-Path $outDir '_primary.tmp') $cards (New-Object byte[] 0)
    $primary = [System.IO.File]::ReadAllBytes((Join-Path $outDir '_primary.tmp'))
    Remove-Item (Join-Path $outDir '_primary.tmp')

    $ext = @(
        (New-Card 'XTENSION' 'BINTABLE' 'binary table extension' -AsString)
        (New-Card 'BITPIX'   8)
        (New-Card 'NAXIS'    2)
        (New-Card 'NAXIS1'   24 'bytes per row')
        (New-Card 'NAXIS2'   $fz.Rows 'one row per tile')
        (New-Card 'PCOUNT'   $fz.HeapLen 'heap size')
        (New-Card 'GCOUNT'   1)
        (New-Card 'TFIELDS'  3)
        (New-Card 'TTYPE1'   'COMPRESSED_DATA' '' -AsString)
        (New-Card 'TFORM1'   ("1PB(" + $fz.MaxElem + ")") '' -AsString)
        (New-Card 'TTYPE2'   'ZSCALE' '' -AsString)
        (New-Card 'TFORM2'   '1D' '' -AsString)
        (New-Card 'TTYPE3'   'ZZERO' '' -AsString)
        (New-Card 'TFORM3'   '1D' '' -AsString)
        (New-Card 'ZIMAGE'   'T' 'this table holds a compressed image')
        (New-Card 'ZBITPIX'  -32 'BITPIX of the image')
        (New-Card 'ZNAXIS'   3)
        (New-Card 'ZNAXIS1'  $W)
        (New-Card 'ZNAXIS2'  $H)
        (New-Card 'ZNAXIS3'  $planes)
        (New-Card 'ZTILE1'   $W 'one tile per row')
        (New-Card 'ZTILE2'   1)
        (New-Card 'ZTILE3'   1)
        (New-Card 'ZCMPTYPE' 'RICE_1' '' -AsString)
        (New-Card 'ZNAME1'   'BLOCKSIZE' '' -AsString)
        (New-Card 'ZVAL1'    $blocksize)
        (New-Card 'ZNAME2'   'BYTEPIX' '' -AsString)
        (New-Card 'ZVAL2'    4)
        (New-Card 'ZQUANTIZ' 'SUBTRACTIVE_DITHER_2' '' -AsString)
        (New-Card 'ZDITHER0' $dither0 'dither seed')
        (New-Card 'INSTRUME' 'Synthetic' 'not a real camera' -AsString)
        (New-Card 'PROGRAM'  'make-fixture.ps1' '' -AsString)
        (New-Card 'OBJECT'   'Rice probe' '' -AsString)
        (New-Card 'EXPTIME'  '600.' 'seconds')
    )
    $extPath = Join-Path $outDir '_ext.tmp'
    Write-Fits $extPath $ext $fz.Data
    $extBytes = [System.IO.File]::ReadAllBytes($extPath)
    Remove-Item $extPath

    $final = Join-Path $outDir 'fixture-rice.fit.fz'
    $all = New-Object byte[] ($primary.Length + $extBytes.Length)
    [Array]::Copy($primary, 0, $all, 0, $primary.Length)
    [Array]::Copy($extBytes, 0, $all, $primary.Length, $extBytes.Length)
    [System.IO.File]::WriteAllBytes($final, $all)
    Write-Host ("  wrote {0} - {1:N0} bytes" -f $final, $all.Length)
}

# -------------------------------------------------------------- nonlinear
if ($Only -eq 'all' -or $Only -eq 'nonlinear') {
    # Already stretched: median around 0.25 and HISTORY cards that name an
    # autostretch, which is what nonLinear = median >= 0.05 OR (history AND
    # median >= 0.02) is there to catch.
    $W = 900; $H = 600; $planes = 3
    Write-Host "fixture-nonlinear.fit  ($W x $H x $planes, float32, TOP-DOWN, already stretched)"

    $img = [FitsFixture]::Scene($W, $H, $planes, 20260906, 0.012, 0.0006, 0.30)
    # Apply a midtones transfer so the frame really is non-linear, rather than
    # being a linear frame with a lie in the header.
    #
    # m = MTF(background, 0.25) is the value that lands the linear background on
    # a median of about 0.25 — where a frame someone already stretched in Siril
    # actually sits. A harsher midtones pushes the median to 0.7 and the fixture
    # stops representing the case the non-linear branch was written for.
    [FitsFixture]::Mtf($img, 0.0448)

    $cards = @(
        (New-Card 'SIMPLE'   'T'  'conforms to FITS standard')
        (New-Card 'BITPIX'   -32  'IEEE single precision')
        (New-Card 'NAXIS'    3)
        (New-Card 'NAXIS1'   $W)
        (New-Card 'NAXIS2'   $H)
        (New-Card 'NAXIS3'   $planes)
        (New-Card 'ROWORDER' 'TOP-DOWN' 'first row is image top' -AsString)
        (New-Card 'INSTRUME' 'Synthetic' 'not a real camera' -AsString)
        (New-Card 'PROGRAM'  'make-fixture.ps1' '' -AsString)
        (New-Card 'OBJECT'   'Nonlinear probe' '' -AsString)
        (New-Card 'EXPTIME'  '900.' 'seconds')
        ('HISTORY Autostretch (midtones transfer function) applied'.PadRight(80))
        ('HISTORY Histogram transformation, unlinked channels'.PadRight(80))
    )
    Write-Fits (Join-Path $outDir 'fixture-nonlinear.fit') $cards `
               ([FitsFixture]::FloatBytes($img, $W, $H, $planes, $false))
}

# --------------------------------------------------------------- gradient
if ($Only -eq 'all' -or $Only -eq 'gradient') {
    # 1600 x 1200 is load-bearing, not a round number: at samplesPerRow 12 the
    # grid is 12 x 9, and PREVIEW_EDGE 1024 gives a preview factor of 2, so the
    # fixture exercises the boxSize scaling of section 2.1 - a sample box has to
    # mean the same patch of sky in the preview and in the full render.
    $W = 1600; $H = 1200; $planes = 3
    Write-Host "fixture-gradient.fit  ($W x $H x $planes, float32, TOP-DOWN, known gradient)"

    # ---- the truth ------------------------------------------------------
    #
    # These numbers are the fixture's reason to exist. Every other check in the
    # suite compares this code against itself (goldens) or against a second
    # implementation that was handed this code's formula (the Python). Both are
    # blind to a wrong formula. These coefficients are not: they are written
    # into the file by the generator and read back by the test, so "is the
    # fitted model the gradient I put in?" has an answer that neither
    # implementation can influence.
    #
    # Levels are chosen so the frame stays clearly linear. The mean lands near
    # 0.0159 and the maximum near 0.023; the non-linear branch triggers at
    # median >= 0.05, or >= 0.02 with a stretch recorded in HISTORY. The HISTORY
    # cards below are deliberately worded to match none of the STRETCH_HISTORY
    # patterns in run.js - no "autostretch", no "histogram transf", no
    # "midtone", no "curve". Both guards, because one of them is a regex.
    $coefR = @(0.0121, 0.0071, 0.0041, -0.0024, 0.0014, 0.0011)
    $coefG = @(0.0110, 0.0062, 0.0038, -0.0021, 0.0013, 0.0009)
    $coefB = @(0.0101, 0.0053, 0.0035, -0.0018, 0.0011, 0.0008)

    # cx, cy, a, b, peak, k.  Area of the R<=1 ellipse over the frame area is
    # pi*a*b/(W*H) = pi*343*214/1920000 = 12.0%, which is the fraction of the
    # frame M31 occupied in the partner's own image (section 4).
    $obj     = @(430.0, 880.0, 343.0, 214.0, 0.050, 3.0)
    $objTint = @(1.05, 1.00, 0.95)

    # Probe stars, at the centres a 12 x 9 grid with edgeMargin 0.02 would use.
    # The grid is not binding - the sampler is not written yet - so the contract
    # is only that these positions are recorded. A test finds whichever boxes
    # contain them and asserts those box medians still track the gradient.
    # Placed clear of the object, so a failure means "the star broke the median"
    # and not "the object did".
    $probes    = @(218.0,216.0, 606.0,216.0, 994.0,216.0, 1382.0,216.0,
                   1382.0,600.0, 1382.0,856.0, 994.0,856.0, 1252.0,1100.0)
    $probeAmp  = 0.450
    $probeSig  = 2.2
    $noiseSig  = 0.0012
    $nField    = 300
    $fieldSeed = 20260907
    $noiseSeed = 20260908

    # ---- the cards, written from the same variables ---------------------
    function Fmt6([double]$v) { return $v.ToString('0.000000000', [cultureinfo]::InvariantCulture) }
    function Hist([string]$t) {
        if ($t.Length -gt 72) { throw "HISTORY text too long ($($t.Length)): $t" }
        return ('HISTORY ' + $t).PadRight(80)
    }
    function CoefRows([string]$ch, [double[]]$k) {
        return @(
            (Hist ("GRADIENT $ch A0=" + (Fmt6 $k[0]) + ' A1=' + (Fmt6 $k[1]) + ' A2=' + (Fmt6 $k[2]))),
            (Hist ("GRADIENT $ch A3=" + (Fmt6 $k[3]) + ' A4=' + (Fmt6 $k[4]) + ' A5=' + (Fmt6 $k[5])))
        )
    }

    $pxA = ($probes[0..7]  | ForEach-Object { $_.ToString('0', [cultureinfo]::InvariantCulture) })
    $pxB = ($probes[8..15] | ForEach-Object { $_.ToString('0', [cultureinfo]::InvariantCulture) })
    $probeRowA = "$($pxA[0]),$($pxA[1]) $($pxA[2]),$($pxA[3]) $($pxA[4]),$($pxA[5]) $($pxA[6]),$($pxA[7])"
    $probeRowB = "$($pxB[0]),$($pxB[1]) $($pxB[2]),$($pxB[3]) $($pxB[4]),$($pxB[5]) $($pxB[6]),$($pxB[7])"
    $areaPct = 100.0 * [Math]::PI * $obj[2] * $obj[3] / ($W * $H)

    $cards = @(
        (New-Card 'SIMPLE'   'T'  'conforms to FITS standard')
        (New-Card 'BITPIX'   -32  'IEEE single precision')
        (New-Card 'NAXIS'    3)
        (New-Card 'NAXIS1'   $W)
        (New-Card 'NAXIS2'   $H)
        (New-Card 'NAXIS3'   $planes)
        (New-Card 'ROWORDER' 'TOP-DOWN' 'first row is image top' -AsString)
        (New-Card 'INSTRUME' 'Synthetic' 'not a real camera' -AsString)
        (New-Card 'PROGRAM'  'make-fixture.ps1' '' -AsString)
        (New-Card 'OBJECT'   'Gradient probe' '' -AsString)
        (New-Card 'EXPTIME'  '600.' 'seconds')
        (Hist 'GRADIENT synthetic background, known by construction.')
        (Hist 'GRADIENT g(u,v) = A0 + A1*u + A2*v + A3*u^2 + A4*v^2 + A5*u*v')
        (Hist 'GRADIENT u = x/(NAXIS1-1)  v = y/(NAXIS2-1)  image coords')
        (Hist 'GRADIENT ROWORDER is TOP-DOWN so v=0 is the first stored row.')
    ) + (CoefRows 'R' $coefR) + (CoefRows 'G' $coefG) + (CoefRows 'B' $coefB) + @(
        (Hist 'OBJECT extended source added on top: I = PEAK*exp(-K*R)')
        (Hist 'OBJECT R = hypot((x-CX)/A, (y-CY)/B), per-channel tint below')
        (Hist ("OBJECT CX=$($obj[0]) CY=$($obj[1]) A=$($obj[2]) B=$($obj[3]) PEAK=" + (Fmt6 $obj[4]) + " K=$($obj[5])"))
        (Hist ("OBJECT tint R/G/B = $($objTint[0])/$($objTint[1])/$($objTint[2]), R<=1 covers " + $areaPct.ToString('0.00', [cultureinfo]::InvariantCulture) + ' pct'))
        (Hist ("PROBE bright stars, PEAK=" + (Fmt6 $probeAmp) + " SIGMA=$probeSig, positions recorded"))
        (Hist "PROBE x,y: $probeRowA")
        (Hist "PROBE x,y: $probeRowB")
        (Hist ("FIELD $nField ordinary stars, seed $fieldSeed, not part of the truth"))
        (Hist ("NOISE gaussian sigma=" + (Fmt6 $noiseSig) + ", seed $noiseSeed, added last"))
        (Hist 'TRUTH the GRADIENT rows above came from neither implementation.')
        (Hist 'TRUTH See modulo-1-spec.md section 5 for why that matters.')
    )

    $img = [FitsFixture]::GradientScene($W, $H, $noiseSeed,
                                        $coefR, $coefG, $coefB, $noiseSig,
                                        $obj, $objTint, $probes,
                                        $probeAmp, $probeSig, $nField, $fieldSeed)

    Write-Fits (Join-Path $outDir 'fixture-gradient.fit') $cards `
               ([FitsFixture]::FloatBytes($img, $W, $H, $planes, $false))
}

Write-Host ''
Get-ChildItem $outDir -File | ForEach-Object { "  {0,12:N0}  {1}" -f $_.Length, $_.Name }
