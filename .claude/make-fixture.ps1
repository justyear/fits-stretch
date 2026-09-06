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
# Not part of the deliverable — test fixtures only.

param([ValidateSet('all', 'seestar', 'rice', 'nonlinear')][string]$Only = 'all')

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

Write-Host ''
Get-ChildItem $outDir -File | ForEach-Object { "  {0,12:N0}  {1}" -f $_.Length, $_.Name }
