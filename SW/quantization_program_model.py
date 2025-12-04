import numpy as np

# ============================================================================
# KWANTYZACJA: r = S(q - Z)
# ============================================================================

def quantize(value, bits=8):
    """
    Kwantyzuje do zadanej precyzji.
    Zwraca: (kwantyzowana_wartosc, skala, zero_point)
    """
    r_min = float(np.min(value))
    r_max = float(np.max(value))
    
    
    q_min, q_max = 0, 2 ** bits - 1
    
    # Skala i zero-point
    S = (r_max - r_min) / (q_max - q_min)
    Z = int(np.round(q_min - r_min / S))
    Z = np.clip(Z, q_min, q_max)
    
    # Kwantyzacja
    q = np.round(value / S + Z)
    q = np.clip(q, q_min, q_max).astype(np.uint8 if bits == 8 else np.int32)
    
    return q, S, Z


def dequantize(q, S, Z, save_to_file=None):
    """Dekwantyzacja: r = S(q - Z)"""
    dequant = S * (q.astype(np.float32) - Z)
    r = len(dequant)

    if save_to_file:

        with open(save_to_file, "w") as f:
            # dekwantyzacja
            f.write(f"OUTPUT DEQUANTIZED:\n")
            for i in range(0, r):
                f.write(f"{dequant[i]}")
                f.write(", ")
            f.write("\n\n")


    return dequant



# ============================================================================
# GENEROWANIE DANYCH I ZAPIS DO PLIKU
# ============================================================================

def generate_data(N, M, save_to_file=None):
    """
    Generuje losowe wejście, wagi i biasy. Zapisuje je do pliku.
    """
    weights = np.random.uniform(-1.0, 1.0, size=(M, N)).astype(np.float32)
    biases = np.random.uniform(-0.5, 0.5, size=(M,)).astype(np.float32)
    input_data = np.random.uniform(-2.0, 2.0, size=(N,)).astype(np.float32)

    if save_to_file:

        with open(save_to_file, "w") as f:
            # INPUT
            f.write(f"INPUT [{N}]:\n")
            for i in range(N):
                f.write(f"{input_data[i]:8.4f}")
                f.write(", ")
            f.write("\n\n")

            # WEIGHTS
            f.write(f"WEIGHTS [{M} x {N}]:\n")
            for i in range(M):
                for j in range(N):
                    f.write(f"{weights[i, j]:8.4f}, ")
                f.write("\n")
            f.write("\n")

            # BIASES
            f.write(f"BIASES [{M}]:\n")
            for i in range(M):
                f.write(f"{biases[i]:8.4f}, ")

    return weights, biases, input_data


# ============================================================================
# KWANTYZACJA WSZYSTKICH TENSORÓW
# ============================================================================

def quantize_all(weights, biases, input_data, 
                 weight_bits=8, input_bits=8, output_bits=8, bias_bits=32):
    """
    Kwantyzuje wagi, wejście i zwraca parametry dla biasów i wyjścia.
    """
    # 1. Kwantyzacja wag
    q_weights, S_w, Z_w = quantize(weights, bits=weight_bits)
    
    # 2. Kwantyzacja wejścia
    q_input, S_in, Z_in = quantize(input_data, bits=input_bits)
    
    # 3. Parametry wyjścia
    output_float_temp = np.dot(weights, input_data) + biases
    output_float_temp = np.clip(output_float_temp, 0, 6)  # ReLU6
    _, S_out, Z_out = quantize(output_float_temp, bits=output_bits)
    
    S_bias = S_in * S_w
    Z_bias = 0
    
    q_biases = np.round(biases / S_bias).astype(np.int32)

    
    return {
        'q_weights': q_weights,
        'q_input': q_input,
        'q_biases': q_biases,
        'S_w': S_w, 'Z_w': Z_w,
        'S_in': S_in, 'Z_in': Z_in,
        'S_out': S_out, 'Z_out': Z_out,
        'S_bias': S_bias, 'Z_bias': Z_bias,
        'weight_bits': weight_bits,
        'input_bits': input_bits,
        'output_bits': output_bits,
        'bias_bits': bias_bits
    }


# ============================================================================
# OBLICZENIE PARAMETRÓW FPGA 
# ============================================================================

def compute_fpga_params(q_data, N):
    """ 
    super_bias and params

    """
    S_in = q_data['S_in']
    S_w = q_data['S_w']
    S_out = q_data['S_out']
    Z_in = q_data['Z_in']
    Z_w = q_data['Z_w']
    Z_out = q_data['Z_out']
    
    q_weights = q_data['q_weights']
    q_biases = q_data['q_biases']
    
    M = (S_in * S_w) / S_out
    
    # Sumy pomocnicze
    aw = np.sum(q_weights, axis=1, dtype=np.int32)
    
    # ai: suma wejścia (obliczana w runtime)

    
    # Super bias calculation
    term_inside = q_biases + (N * Z_in * Z_w) - (Z_in * aw)
    super_bias = M * term_inside + Z_out
    
    return {
        'M': M,
        'aw': aw,
        'super_bias': super_bias
    }


# ============================================================================
# OBLICZANIE SKWANTYZOWANEGO WYJŚCIA
# ============================================================================

def Y_quantized(q_data, fpga_params, save_to_file=None):
    """
    q_out = M * [sum(qw*qi) - Zw*ai] + super_bias
    """
    q_weights = q_data['q_weights']
    q_input = q_data['q_input']
    Z_w = q_data['Z_w']
    output_bits = q_data['output_bits']

    M = fpga_params['M']
    super_bias = fpga_params['super_bias']
    
    # ai (suma input) 
    ai = np.sum(q_input, dtype=np.int32)
    
    # mnóżenie macierzowe - akumulator
    mat_mul = np.dot(q_weights.astype(np.int32), q_input.astype(np.int32))
    
    # obliczanie wyniku
    q_output_float = M * (mat_mul - Z_w * ai) + super_bias
    
    # saturacja
    q_output = np.round(q_output_float)
    
    q_min = 0
    q_max = (2 ** output_bits) - 1
    q_output = np.clip(q_output, q_min, q_max).astype(np.uint8)
    
    M_range = len(q_output)
    # print(M_range)

    # zapis do pliku
    if save_to_file:

        with open(save_to_file, "w") as f:
            # OUTPUT
            f.write(f"OUTPUT:\n")
            for i in range(0, M_range):
                f.write(f"{q_output[i]}")
                f.write(", ")
            f.write("\n\n")
            
    return q_output


# ============================================================================
# OBLICZANIE WYJŚCIA W FLOAT (DLA PORÓWNANIA)
# ============================================================================

def Y_float(weights, biases, input_data):
    """Obliczenie wyjścia w float32 dla porównania"""
    output = np.dot(weights, input_data) + biases
    output = np.clip(output, 0, 6)  # ReLU6
    return output


# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":

    N = 128
    M = 64
    
    # Szerokość danych
    WEIGHT_BITS = 8
    INPUT_BITS = 8
    OUTPUT_BITS = 8
    BIAS_BITS = 32
    
    # Generowanie danych
    weights, biases, input_data = generate_data(N, M, save_to_file=".\\data.txt")
    
    # Kwantyzacja
    q_data = quantize_all(weights, biases, input_data, 
                          WEIGHT_BITS, INPUT_BITS, OUTPUT_BITS, BIAS_BITS)
    
    # Parametry FPGA
    fpga_params = compute_fpga_params(q_data, N)
    
    # Wyjście kwantyzowane
    q_output = Y_quantized(q_data, fpga_params, save_to_file=".\\OUTPUT_quantized.txt")
    
    # Dekwantyzacja wyniku
    output_dequant = dequantize(q_output, q_data['S_out'], q_data['Z_out'], save_to_file=".\\OUTPUT_dequant.txt")
    
    # Wyjście float (dla porównania)
    output_float = Y_float(weights, biases, input_data)
    
    # Błedy
    max_diff = np.max(np.abs(output_dequant - output_float)) 
    mean_diff = np.mean(np.abs(output_dequant - output_float)) 
    relative_error = mean_diff / (np.mean(np.abs(output_float)) + 1e-8)
    
    # Wyniki
    print(f"\n" + "="*70)
    print("DANE KWANTYZACJI:")
    print(f"  Wagi:    S={q_data['S_w']:.6f}, Z={q_data['Z_w']}")
    print(f"  Wejście: S={q_data['S_in']:.6f}, Z={q_data['Z_in']}")
    print(f"  Wyjście: S={q_data['S_out']:.6f}, Z={q_data['Z_out']}")
    print(f"  Biasy:   S={q_data['S_bias']:.6f}, Z={q_data['Z_bias']}")
    
    print(f"\nPARAMETRY FPGA:")
    print(f"  M (multiplier):     {fpga_params['M']:.6f}")
    # print(f"  ai (suma input):    {fpga_params['ai']}")
    print(f"  aw[:3]:             {fpga_params['aw'][:3]}")
    print(f"  super_bias[:3]:     {fpga_params['super_bias'][:3]}")
    
    print(f"\nWYNIKI (pierwsze 5 elementów):")
    print(f"  Float:       {output_float[:5]}")
    print(f"  Quantized:   {q_output[:5]}")
    print(f"  Dequantized: {output_dequant[:5]}")
    
    print(f"\nBŁĘDY:")
    print(f"  Maksymalny:     {max_diff* 100:.6f}%")
    print(f"  Średni:         {mean_diff* 100:.6f}%")

    if relative_error < 0.015:
        print(f"\nKwantyzacja działa poprawnie!")
    else:
        print(f"\nBłąd większy niż oczekiwany (>1.5%)")
    
