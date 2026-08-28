// CRT Shader SDL3 GPU:lle
Texture2D vram_texture : register(t0);
SamplerState texture_sampler : register(s0);

struct PixelInput {
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
};

// Tehosteiden voimakkuussäädöt
static const float distortion = 0.10; // Ruudun kaarevuus (0.0 = suora)
static const float scanline_intensity = 0.25; // Viivojen tummuus

// Funktio, joka laskee ruudun vääristymän (CRT-kaarevuus)
float2 radial_distortion(float2 coord) {
    float2 cc = coord - 0.5;
    float dist = dot(cc, cc);
    return coord + cc * dist * distortion;
}

float4 main(PixelInput input) : SV_TARGET {
    // 1. Lasketaan kaareva koordinaatti
    float2 uv = radial_distortion(input.uv);
    
    // Jos koordinaatti menee ruudun ulkopuolelle, piirretään mustaa (pyöreät kulmat)
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }
    
    // 2. Haetaan alkuperäinen kuva emulaattorin VRAM-tekstuurista
    float4 color = vram_texture.Sample(texture_sampler, uv);
    
    // 3. Lasketaan Scanline-vaakaradat
    // Käytetään sini-aaltoa y-akselilla simuloimaan putken juovia
    float scanline = sin(uv.y * 800.0) * scanline_intensity;
    color.rgb -= scanline;
    
    // Vignette (reunojen lievä tummennus)
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = clamp(pow(16.0 * vignette, 0.25), 0.0, 1.0);
    color.rgb *= vignette;

    return color;
}
