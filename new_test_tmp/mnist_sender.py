import socket
import struct
import time
import numpy as np
from torchvision import datasets, transforms

MERCURY_IP = '192.168.0.50'  # update to your board IP
PORT = 5000
NUM_IMAGES = 100

def load_mnist():
    dataset = datasets.MNIST(
        root='./mnist_data',
        train=False,
        download=True,
        transform=transforms.ToTensor()
    )
    images = []
    labels = []
    for img, label in dataset:
        images.append(img.numpy().squeeze())  # shape (28, 28)
        labels.append(label)
    return images, labels

def send_image(sock, image):
    vector = image.flatten().astype(np.float32) / 255.0
    sock.sendall(struct.pack('784f', *vector))

    # Receive 10 floats back
    data = b''
    while len(data) < 40:
        chunk = sock.recv(40 - len(data))
        if not chunk:
            raise ConnectionError('Connection lost')
        data += chunk

    output_vector = list(struct.unpack('10f', data))
    return output_vector

def analyze_results(results):
    print('\n' + '='*50)
    print('RESULTS ANALYSIS')
    print('='*50)

    correct = sum(1 for r in results if r['correct'])
    total = len(results)
    times = [r['time_ms'] for r in results]

    print(f'Accuracy:     {correct}/{total} = {100*correct/total:.1f}%')
    print(f'Avg latency:  {np.mean(times):.2f} ms')
    print(f'Min latency:  {np.min(times):.2f} ms')
    print(f'Max latency:  {np.max(times):.2f} ms')
    print(f'Std latency:  {np.std(times):.2f} ms')
    print(f'Throughput:   {1000/np.mean(times):.1f} images/sec')

    print('\nPer-class accuracy:')
    for digit in range(10):
        digit_results = [r for r in results if r['label'] == digit]
        if digit_results:
            digit_correct = sum(1 for r in digit_results if r['correct'])
            print(f'  Digit {digit}: {digit_correct}/{len(digit_results)} '
                  f'= {100*digit_correct/len(digit_results):.0f}%')

    print('\nMisclassifications:')
    wrong = [r for r in results if not r['correct']]
    if wrong:
        for r in wrong[:10]:
            print(f'  Image {r["idx"]}: label={r["label"]}, '
                  f'predicted={r["predicted"]}, '
                  f'confidence={r["confidence"]:.3f}')
    else:
        print('  None!')
    print('='*50)

def main():
    print('Loading MNIST test data...')
    images, labels = load_mnist()
    print(f'Loaded {len(images)} test images')

    print(f'\nConnecting to Mercury at {MERCURY_IP}:{PORT}...')
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((MERCURY_IP, PORT))
    print('Connected!\n')

    results = []

    for i in range(NUM_IMAGES):
        image = images[i]
        label = labels[i]

        t_start = time.time()
        output_vector = send_image(sock, image)
        t_end = time.time()

        predicted = output_vector.index(max(output_vector))
        confidence = max(output_vector)
        time_ms = (t_end - t_start) * 1000
        correct = (predicted == label)

        results.append({
            'idx': i,
            'label': label,
            'predicted': predicted,
            'confidence': confidence,
            'output_vector': output_vector,
            'time_ms': time_ms,
            'correct': correct
        })

        status = 'OK' if correct else 'WRONG'
        print(f'[{i+1:3d}/{NUM_IMAGES}] {status} '
              f'label={label} predicted={predicted} '
              f'conf={confidence:.3f} time={time_ms:.1f}ms')

    sock.close()
    analyze_results(results)

    import csv
    with open('results.csv', 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=[
            'idx', 'label', 'predicted', 'confidence', 'time_ms', 'correct'])
        writer.writeheader()
        for r in results:
            writer.writerow({k: r[k] for k in [
                'idx', 'label', 'predicted', 'confidence', 'time_ms', 'correct']})
    print('\nResults saved to results.csv')

if __name__ == '__main__':
    main()