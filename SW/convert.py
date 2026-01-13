import numpy as np


def toBin(num, prec):
    assert isinstance(num, np.integer)
    num = int(num)
    binary = list(bin(num)[2:])
    assert len(binary) <= prec
    return "".join((["0" for i in range(prec)] + binary)[-prec:])


def toHex(num, prec):
    assert isinstance(num, np.integer)
    num = int(num)
    leng = prec // 4 if prec // 4 == prec / 4 else prec // 4 + 1
    binary = list(hex(num)[2:])
    assert len(binary) <= leng
    return "".join((["0" for i in range(leng)] + binary)[-leng:])


class ToMem:
    def __init__(self, feature_prec, bias_prec):
        self.features = []
        self.out = []
        self.feature_prec = feature_prec
        self.bias_prec = bias_prec

    def addFeature(self, feature):
        self.features.append(feature)

    def addOut(self, out):
        self.out.append(out)

    def setWeights(self, weights):
        self.weights = weights  # Możliwe ze trzeba reshape

    def setSuperbias(self, superbias):
        self.superbias = superbias

    def saveFeatures(self):
        with open("../HW/features.mem", "w") as f:
            for i in self.features:
                for j in i:
                    f.write(toBin(j, self.feature_prec)+"\n")

    def saveOut(self):
        with open("../HW/out_truth.mem", "w") as f:
            for i in self.out:
                for j in i:
                    f.write(toBin(j, self.feature_prec)+"\n")

    def saveWeights(self, split=1):
        assert len(self.weights) == len(self.superbias)
        with open("../HW/weights.mem", "w") as f:
            # for i in range(len(self.superbias)*split):
            # f.write(toHex(self.superbias[i], self.bias_prec)+"".join([toHex(j, self.feature_prec) for j in self.weights[i]])+"\n")
            weights_split = [np.array_split(i, split) for i in self.weights]
            weights_split_flat = [x for xs in weights_split for x in xs]

            tmp = ""
            for i in range(len(weights_split_flat)):
                if (i < len(self.superbias)):
                    tmp += toHex(self.superbias[i], self.bias_prec)
                else:
                    tmp += toHex(np.int32(0), self.bias_prec)
                tmp += "".join([toHex(j, self.feature_prec) for j in weights_split_flat[i]])
                tmp += "\n"

                f.write(tmp)
                tmp = ""


saver = ToMem(8, 32)
saver.setSuperbias(np.abs(np.random.randint(low=0, high=2**31-1, size=8, dtype=np.int32)))
saver.setWeights(np.abs(np.random.randint(low=0, high=2**7-1, size=(8, 8), dtype=np.int8)))

saver.saveWeights(4)
