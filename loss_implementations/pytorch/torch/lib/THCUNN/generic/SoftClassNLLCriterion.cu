#ifndef THC_GENERIC_FILE
#define THC_GENERIC_FILE "generic/SoftClassNLLCriterion.cu"
#else

void THNN_(SoftClassNLLCriterion_updateOutput)(
           THCState *state,
           THCTensor *input,
           THCIndexTensor *target,
           THCTensor *output,
           bool sizeAverage,
           THCTensor *weights,
           THCTensor *total_weight) {
  THCUNN_check_dim_size(state, output, 1, 0, 1);
  THCUNN_check_dim_size(state, total_weight, 1, 0, 1);


  int n_dims = THCTensor_(nDimension)(state, input);
  int n_classes = THCTensor_(size)(state, input, n_dims - 1);
  int n_weights = 10; //THCIndexTensor_(size)(state, target, n_dims -1);

  if (weights) {
    THCUNN_assertSameGPU(
      state, 5, input, target, weights, output, total_weight
    );
  } else {
    THCUNN_assertSameGPU(
      state, 4, input, target, output, total_weight
    );
  }

  THArgCheck(n_dims <= 2 && n_dims > 0, 2, "vector or matrix expected");

  long batch_size = n_dims == 1 ? 1 : THCTensor_(size)(state, input, 0);
  long num_targets = THCudaLongTensor_size(state, target, 0);
  THArgCheck(batch_size == num_targets,
      2, "mismatch between the batch size of input (%ld) and that of target (%ld)",
      batch_size, num_targets);

  if (weights && THCTensor_(size)(state, weights, n_dims -1) != n_weights) {
    THCDescBuff s1 = THCTensor_(sizeDesc)(state, weights);
    THError("weight tensor should be defined for all %d targets "
            " but got weight tensor of shape: %s", n_weights, s1.str);
  }

  input = THCTensor_(newContiguous)(state, input);
  weights = weights ? THCTensor_(newContiguous)(state, weights) : NULL;
  target = THCIndexTensor_(newContiguous)(state, target);

  real *input_data = THCTensor_(data)(state, input);
  real *weights_data = weights ? THCTensor_(data)(state, weights) : NULL;
  THCIndex_t  *target_data = THCIndexTensor_(data)(state, target);
  real *output_data = THCTensor_(data)(state, output);
  real *total_weight_data = THCTensor_(data)(state, total_weight);

  if (THCTensor_(nDimension)(state, input) == 1) {
    cunn_SoftClassNLLCriterion_updateOutput_kernel1<real>
      <<<1, 1, 0, THCState_getCurrentStream(state)>>>(
        output_data,
        total_weight_data,
        input_data,
        target_data,
        weights_data,
        sizeAverage,
        n_classes
    );

  } else if (THCTensor_(nDimension)(state, input) == 2) {
    cunn_SoftClassNLLCriterion_updateOutput_kernel<real, accreal>
      <<<1, NTHREADS, 0, THCState_getCurrentStream(state)>>>(
        output_data,
        total_weight_data,
        input_data,
        target_data,
        weights_data,
        sizeAverage,
        THCTensor_(size)(state, input, 0),
        THCTensor_(size)(state, input, 1),
        n_classes,
        n_weights
    );
  }
  THCudaCheck(cudaGetLastError());

  if (weights) {
    THCTensor_(free)(state, weights);
  }
  THCIndexTensor_(free)(state, target);
  THCTensor_(free)(state, input);
}

void THNN_(SoftClassNLLCriterion_updateGradInput)(
           THCState *state,
           THCTensor *input,
           THCIndexTensor *target,
           THCTensor *gradInput,
           bool sizeAverage,
           THCTensor *weights,
           THCTensor *total_weight) {

  int n_dims = THCTensor_(nDimension)(state, input);
  int n_classes = THCTensor_(size)(state, input, n_dims - 1);
  int n_weights = 10; //THCIndexTensor_(size)(state, target, n_dims -1);

  THArgCheck(THCTensor_(isContiguous)(state, gradInput), 4, "gradInput must be contiguous");

  if (weights) {
    THCUNN_assertSameGPU(
      state, 5, weights, input, target, gradInput, total_weight
    );
  }
  else {
    THCUNN_assertSameGPU(
      state, 4, input, target, gradInput, total_weight
    );
  }

  THArgCheck(n_dims <= 2 && n_dims > 0, 2, "vector or matrix expected");

  long batch_size = n_dims == 1 ? 1 : THCTensor_(size)(state, input, 0);
  long num_targets = THCudaLongTensor_size(state, target, 0);
  THArgCheck(batch_size == num_targets,
      2, "mismatch between the batch size of input (%ld) and that of target (%ld)",
      batch_size, num_targets);

  if (weights && THCTensor_(size)(state, weights, n_dims -1) != n_weights) {
    THCDescBuff s1 = THCTensor_(sizeDesc)(state, weights);
    THError("weight tensor should be defined for all %d targets "
            " but got weight tensor of shape: %s", n_weights, s1.str);
  }

  weights = weights ? THCTensor_(newContiguous)(state, weights) : NULL;
  target = THCIndexTensor_(newContiguous)(state, target);

  real *weights_data = weights ? THCTensor_(data)(state, weights) : NULL;
  real *gradInput_data = THCTensor_(data)(state, gradInput);
  THCIndex_t  *target_data = THCIndexTensor_(data)(state, target);
  real *total_weight_data = THCTensor_(data)(state, total_weight);

  if (THCTensor_(nDimension)(state, input) == 1) {
    cunn_SoftClassNLLCriterion_updateGradInput_kernel1<real>
      <<<1, 1, 0, THCState_getCurrentStream(state)>>>(
        gradInput_data,
        weights_data,
        target_data,
        total_weight_data,
        sizeAverage,
        n_classes
    );
  } else {
    cunn_SoftClassNLLCriterion_updateGradInput_kernel<real>
      <<<1, NTHREADS, 0, THCState_getCurrentStream(state)>>>(
        gradInput_data,
        target_data,
        weights_data,
        total_weight_data,
        sizeAverage,
        THCTensor_(size)(state, input, 0),
        THCTensor_(size)(state, input, 1),
        n_classes,
        n_weights
    );
  }
  THCudaCheck(cudaGetLastError());

  if (weights) {
    THCTensor_(free)(state, weights);
  }
  THCIndexTensor_(free)(state, target);
}

#endif
