#ifndef RANDOM_INCLUDED
#define RANDOM_INCLUDED

float Rand3dTo1d(float3 value, float3 dotDir = float3(12.9898, 78.233, 37.719))
{
    //make value smaller to avoid artefacts
    float3 smallValue = sin(value);
    //get scalar value from 3d vector
    float random = dot(smallValue, dotDir);
    //make value more random by making it bigger and then taking the factional part
    random = frac(sin(random) * 143758.5453);
    return random;
}

uint NextRandom(inout uint state)
{
    state = state * 747796405 + 2891336453;
    uint result = ((state >> ((state >> 28) + 4)) ^ state) * 277803737;
    result = (result >> 22) ^ result;
    return result;
}

// Returns a random value in range [0, 1)
float RandomValue(inout uint state)
{
    return NextRandom(state) / 4294967296.0; // 2^32
} 

// Random value in normal distribution (with mean=0 and sd=1)
float RandomValueNormalDistribution(inout uint state)
{
	// Thanks to https://stackoverflow.com/a/6178290
    float theta = 2 * PI * RandomValue(state);
    float rho = sqrt(-2 * log(RandomValue(state)));
    return rho * cos(theta);
}

// Calculate a random direction
float3 RandomDirection(inout uint state)
{
	// Thanks to https://math.stackexchange.com/a/1585996
    float x = RandomValueNormalDistribution(state);
    float y = RandomValueNormalDistribution(state);
    float z = RandomValueNormalDistribution(state);
    return normalize(float3(x, y, z));
}

float3 RandomHemisphereDirection(float3 normal, inout uint rngState)
{
    float3 dir = RandomDirection(rngState);
    return dir * sign(dot(normal, dir));
}

float2 RandomPointInCircle(inout uint rngState)
{
    float angle = 2 * PI * RandomValue(rngState);
    float2 pointInCircle = float2(cos(angle), sin(angle));
    return pointInCircle * sqrt(RandomValue(rngState));
}

float Halton(uint base, uint index)
{
    float result = 0;
    float digitWeight = 1;
    while (index > 0u)
    {
        digitWeight = digitWeight / float(base);
        uint nominator = index % base;
        result += float(nominator) * digitWeight;
        index = index / base;
    }
    return result;
}

#endif