/*
 * relu.cu
 *
 *  Created on: Sep 20, 2015
 *      Author: lyx
 */

#include "relu.h"

using namespace global;

namespace layer {

ReLU::ReLU(Layer* _prev, int _output_size, float dropout_rate, float alpha,
		float sigma, float momentum, float weight_decay):
		Neuron(_prev, _output_size, dropout_rate, alpha, sigma) {}

ReLU::~ReLU() {}

void ReLU::forward_activation() {
	float a = 1;
	float b = 0;
	callCudnn(cudnnActivationForward(cudnnHandle, CUDNN_ACTIVATION_RELU, &a,
			t_data, tmp_data, &b, t_data, data));
}

void ReLU::backward_activation() {
	float a = 1;
	float b = 0;
	callCudnn(cudnnActivationBackward(cudnnHandle, CUDNN_ACTIVATION_RELU, &a,
			t_data, data, t_data, next->diff,
			t_data, tmp_data, &b, t_data, tmp_diff));
}

}
