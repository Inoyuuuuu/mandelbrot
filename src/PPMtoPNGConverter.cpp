#include <vector>
#include <fstream>
#include <cstdint>
#include <string>
#include <iostream>
#include <filesystem>
#include <sstream>
#include <cstring>
#include <algorithm>
#include <cctype>
#include <zlib.h>

#include "PPMtoPNGConverter.h"

using namespace std;

void init_crc();
uint32_t crc32(const uint8_t* data, size_t len);
uint32_t adler32(const uint8_t* data, size_t len);
void write_u32(ofstream& f, uint32_t v);
void write_chunk(ofstream& f, const char* type, const vector<uint8_t>& data);
vector<uint8_t> make_zlib_stream(const vector<uint8_t>& rawData);
void write_png(const string& filename, int width, int height, const vector<uint8_t>& rgb);
string next_ppm_token(istream& in);
vector<uint8_t> load_ppm_p6(const string& path, int& w, int& h);

uint32_t crc_table[256];

void init_crc() {
    for (uint32_t i = 0; i < 256; i++) {
        uint32_t c = i;
        for (int k = 0; k < 8; k++) {
            c = (c & 1) ? 0xEDB88320u ^ (c >> 1) : (c >> 1);
        }
        crc_table[i] = c;
    }
}

uint32_t crc32(const uint8_t* data, size_t len) {
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < len; i++) {
        c = crc_table[(c ^ data[i]) & 0xFF] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFFu;
}

uint32_t adler32(const uint8_t* data, size_t len) {
    constexpr uint32_t MOD = 65521;
    uint32_t a = 1, b = 0;
    for (size_t i = 0; i < len; i++) {
        a = (a + data[i]) % MOD;
        b = (b + a) % MOD;
    }
    return (b << 16) | a;
}

void write_u32(ofstream& f, uint32_t v) {
    f.put((v >> 24) & 0xFF);
    f.put((v >> 16) & 0xFF);
    f.put((v >> 8) & 0xFF);
    f.put(v & 0xFF);
}

void write_chunk(ofstream& f, const char* type, const vector<uint8_t>& data) {
    write_u32(f, static_cast<uint32_t>(data.size()));
    f.write(type, 4);
    if (!data.empty()) {
        f.write(reinterpret_cast<const char*>(data.data()), static_cast<std::streamsize>(data.size()));
    }

    vector<uint8_t> crc_input(4 + data.size());
    memcpy(crc_input.data(), type, 4);
    if (!data.empty()) {
        memcpy(crc_input.data() + 4, data.data(), data.size());
    }

    write_u32(f, crc32(crc_input.data(), crc_input.size()));
}

vector<uint8_t> make_zlib_stream(const vector<uint8_t>& raw) {
    uLongf bound = compressBound(raw.size());
    vector<uint8_t> out(bound);
    compress2(out.data(), &bound, raw.data(), raw.size(), Z_BEST_COMPRESSION);
    out.resize(bound);
    return out;
}

string next_ppm_token(istream& in) {
    char c;

    while (in.get(c)) {
        if (isspace(static_cast<unsigned char>(c))) continue;
        if (c == '#') {
            string dummy;
            getline(in, dummy);
            continue;
        }
        string token;
        token.push_back(c);

        while (in.get(c)) {
            if (isspace(static_cast<unsigned char>(c))) break;
            if (c == '#') {
                string dummy;
                getline(in, dummy);
                break;
            }
            token.push_back(c);
        }
        return token;
    }

    return {};
}

vector<uint8_t> load_ppm_p6(const string& path, int& w, int& h) {
    ifstream f(path, ios::binary);
    if (!f.is_open()) {
        throw runtime_error("Failed to open PPM file: " + path);
    }

    string magic = next_ppm_token(f);
    if (magic != "P6") {
        throw runtime_error("Only P6 PPM is supported");
    }

    w = stoi(next_ppm_token(f));
    h = stoi(next_ppm_token(f));
    int maxVal = stoi(next_ppm_token(f));

    if (w <= 0 || h <= 0) {
        throw runtime_error("Invalid PPM dimensions");
    }
    if (maxVal <= 0 || maxVal > 65535) {
        throw runtime_error("Invalid PPM max value");
    }

    // Consume one whitespace byte after the header if present.
    while (true) {
        int ch = f.peek();
        if (ch == EOF) break;
        if (!isspace(static_cast<unsigned char>(ch))) break;
        f.get();
        if (ch == '\n' || ch == '\r') break;
    }

    vector<uint8_t> rgb(static_cast<size_t>(w) * static_cast<size_t>(h) * 3);

    auto scale8 = [maxVal](uint32_t v) -> uint8_t {
        if (maxVal == 255) return static_cast<uint8_t>(v);
        return static_cast<uint8_t>((v * 255u + static_cast<uint32_t>(maxVal / 2)) / static_cast<uint32_t>(maxVal));
    };

    for (int i = 0; i < w * h; i++) {
        uint32_t r, g, b;

        if (maxVal < 256) {
            unsigned char rr, gg, bb;
            f.read(reinterpret_cast<char*>(&rr), 1);
            f.read(reinterpret_cast<char*>(&gg), 1);
            f.read(reinterpret_cast<char*>(&bb), 1);
            if (!f) throw runtime_error("Unexpected EOF while reading PPM data");
            r = rr; g = gg; b = bb;
        } else {
            unsigned char bytes[2];

            f.read(reinterpret_cast<char*>(bytes), 2);
            if (!f) throw runtime_error("Unexpected EOF while reading PPM data");
            r = (bytes[0] << 8) | bytes[1];

            f.read(reinterpret_cast<char*>(bytes), 2);
            if (!f) throw runtime_error("Unexpected EOF while reading PPM data");
            g = (bytes[0] << 8) | bytes[1];

            f.read(reinterpret_cast<char*>(bytes), 2);
            if (!f) throw runtime_error("Unexpected EOF while reading PPM data");
            b = (bytes[0] << 8) | bytes[1];
        }

        rgb[i * 3 + 0] = scale8(r);
        rgb[i * 3 + 1] = scale8(g);
        rgb[i * 3 + 2] = scale8(b);
    }

    return rgb;
}

void write_png(const string& filename, int width, int height, const vector<uint8_t>& rgb) {
    ofstream f(filename, ios::binary);
    if (!f.is_open()) {
        throw runtime_error("Failed to open output PNG: " + filename);
    }

    uint8_t sig[8] = {137, 80, 78, 71, 13, 10, 26, 10};
    f.write(reinterpret_cast<char*>(sig), 8);

    vector<uint8_t> ihdr(13);
    ihdr[0]  = (width >> 24) & 0xFF;
    ihdr[1]  = (width >> 16) & 0xFF;
    ihdr[2]  = (width >> 8) & 0xFF;
    ihdr[3]  = width & 0xFF;
    ihdr[4]  = (height >> 24) & 0xFF;
    ihdr[5]  = (height >> 16) & 0xFF;
    ihdr[6]  = (height >> 8) & 0xFF;
    ihdr[7]  = height & 0xFF;
    ihdr[8]  = 8; // bit depth
    ihdr[9]  = 2; // color type RGB
    ihdr[10] = 0; // compression method
    ihdr[11] = 0; // filter method
    ihdr[12] = 0; // interlace method

    write_chunk(f, "IHDR", ihdr);

    // Raw PNG scanlines: filter byte 0 per row
    vector<uint8_t> raw;
    raw.reserve(static_cast<size_t>(height) * (static_cast<size_t>(width) * 3 + 1));

    for (int y = 0; y < height; y++) {
        raw.push_back(0); // filter type 0
        for (int x = 0; x < width; x++) {
            size_t i = (static_cast<size_t>(y) * width + x) * 3;
            raw.push_back(rgb[i + 0]);
            raw.push_back(rgb[i + 1]);
            raw.push_back(rgb[i + 2]);
        }
    }

    vector<uint8_t> zlibStream = make_zlib_stream(raw);
    write_chunk(f, "IDAT", zlibStream);
    write_chunk(f, "IEND", {});
}

void ppm_to_png(const string& ppmPath, const string& pngPath) {
    init_crc();

    int w, h;
    vector<uint8_t> rgb = load_ppm_p6(ppmPath, w, h);

    write_png(pngPath, w, h, rgb);
    cout << "Saved: " << pngPath << endl;
}