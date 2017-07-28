## tests of PhyloNetworklm

tree_str= "(A:2.5,((B:1,#H1:0.5::0.1):1,(C:1,(D:0.5)#H1:0.5::0.9):1):0.5);"
net = readTopology(tree_str)
preorder!(net)
# printEdges(net)
# plot(net, useEdgeLength = true,  showEdgeLength=true, showGamma=true)

# Rk: Is there a way to check that the branch length are coherent with
# one another (Especialy for hybrids) ?
# Not yet (CA, 2016-12-01).
# Would be great to add functions to calculate distance node - root.
# several such distances depending on path: 2 parent choices at each hybrid

# Ancestral state reconstruction with ready-made matrices
params = ParamsBM(10, 1)
srand(2468) # sets the seed for reproducibility, to debug potential error
sim = simulate(net, params)
Y = sim[:Tips]
X = ones(4, 1)
phynetlm = phyloNetworklm(X, Y, net)
@show phynetlm
# Naive version (GLS)
ntaxa = length(Y)
Vy = phynetlm.Vy
Vyinv = inv(Vy)
XtVyinv = X' * Vyinv
logdetVy = logdet(Vy)
betahat = inv(XtVyinv * X) * XtVyinv * Y
fittedValues =  X * betahat
resids = Y - fittedValues
sigma2hat = 1/ntaxa * (resids' * Vyinv * resids)
# log likelihood
loglik = - 1 / 2 * (ntaxa + ntaxa * log(2 * pi) + ntaxa * log(sigma2hat) + logdetVy)
# null version
nullX = ones(ntaxa, 1)
nullXtVyinv = nullX' * Vyinv
nullresids = Y - nullX * inv(nullXtVyinv * nullX) * nullXtVyinv * Y
nullsigma2hat = 1/ntaxa * (nullresids' * Vyinv * nullresids)
nullloglik = - 1 / 2 * (ntaxa + ntaxa * log(2 * pi) + ntaxa * log(nullsigma2hat) + logdetVy)


@test coef(phynetlm) ≈ betahat
@test nobs(phynetlm) ≈ ntaxa
@test residuals(phynetlm) ≈ resids
@test model_response(phynetlm) ≈ Y
@test predict(phynetlm) ≈ fittedValues
@test dof_residual(phynetlm) ≈ ntaxa-length(betahat)
@test sigma2_estim(phynetlm) ≈ sigma2hat
@test loglikelihood(phynetlm) ≈ loglik
@test vcov(phynetlm) ≈ sigma2hat*ntaxa/(ntaxa-length(betahat))*inv(XtVyinv * X)
@test stderr(phynetlm) ≈ sqrt.(diag(sigma2hat*ntaxa/(ntaxa-length(betahat))*inv(XtVyinv * X)))
@test dof(phynetlm) ≈ length(betahat)+1
@test deviance(phynetlm) ≈ sigma2hat * ntaxa
@test nulldeviance(phynetlm) ≈ nullsigma2hat * ntaxa
@test nullloglikelihood(phynetlm) ≈ nullloglik
@test loglikelihood(phynetlm) ≈ nullloglikelihood(phynetlm)
@test deviance(phynetlm) ≈ nulldeviance(phynetlm)
@test r2(phynetlm) ≈ 1-sigma2hat / nullsigma2hat atol=1e-15
@test adjr2(phynetlm) ≈ 1 - (1 - (1-sigma2hat/nullsigma2hat))*(ntaxa-1)/(ntaxa-length(betahat)) atol=1e-15
@test aic(phynetlm) ≈ -2*loglik+2*(length(betahat)+1)
@test aicc(phynetlm) ≈ -2*loglik+2*(length(betahat)+1)+2(length(betahat)+1)*((length(betahat)+1)+1)/(ntaxa-(length(betahat)+1)-1)
@test bic(phynetlm) ≈ -2*loglik+(length(betahat)+1)*log(ntaxa)

# with data frames
dfr = DataFrame(trait = Y, tipNames = sim.M.tipNames)
fitbis = phyloNetworklm(@formula(trait ~ 1), dfr, net)
#@show fitbis

@test coef(phynetlm) ≈ coef(fitbis)
@test vcov(phynetlm) ≈ vcov(fitbis)
@test nobs(phynetlm) ≈ nobs(fitbis)
@test residuals(phynetlm)[fitbis.model.ind] ≈ residuals(fitbis)
@test model_response(phynetlm)[fitbis.model.ind] ≈ model_response(fitbis)
@test predict(phynetlm)[fitbis.model.ind] ≈ predict(fitbis)
@test dof_residual(phynetlm) ≈ dof_residual(fitbis)
@test sigma2_estim(phynetlm) ≈ sigma2_estim(fitbis)
@test stderr(phynetlm) ≈ stderr(fitbis)
@test confint(phynetlm) ≈ confint(fitbis)
@test loglikelihood(phynetlm) ≈ loglikelihood(fitbis)
@test dof(phynetlm) ≈ dof(fitbis)
@test deviance(phynetlm) ≈ deviance(fitbis)
@test nulldeviance(phynetlm) ≈ nulldeviance(fitbis)
@test nullloglikelihood(phynetlm) ≈ nullloglikelihood(fitbis)
@test r2(phynetlm) ≈ r2(fitbis) atol=1e-15
@test adjr2(phynetlm) ≈ adjr2(fitbis) atol=1e-15
@test aic(phynetlm) ≈ aic(fitbis)
@test aicc(phynetlm) ≈ aicc(fitbis)
@test bic(phynetlm) ≈ bic(fitbis)
@test mu_estim(phynetlm) ≈ mu_estim(fitbis)

## Pagel's Lambda
fitlam = phyloNetworklm(@formula(trait ~ 1), dfr, net, model = "lambda", fixedValue=1.0)
@show fitlam

@test lambda_estim(fitlam) ≈ 1.0
@test coef(fitlam) ≈ coef(fitbis)
@test vcov(fitlam) ≈ vcov(fitbis)
@test nobs(fitlam) ≈ nobs(fitbis)
@test residuals(fitlam)[fitbis.model.ind] ≈ residuals(fitbis)
@test model_response(fitlam)[fitbis.model.ind] ≈ model_response(fitbis)
@test predict(fitlam)[fitbis.model.ind] ≈ predict(fitbis)
@test dof_residual(fitlam) ≈ dof_residual(fitbis)
@test sigma2_estim(fitlam) ≈ sigma2_estim(fitbis)
@test stderr(fitlam) ≈ stderr(fitbis)
@test confint(fitlam) ≈ confint(fitbis)
@test loglikelihood(fitlam) ≈ loglikelihood(fitbis)
@test dof(fitlam) ≈ dof(fitbis) + 1
@test deviance(fitlam) ≈ deviance(fitbis)
@test nulldeviance(fitlam) ≈ nulldeviance(fitbis)
@test nullloglikelihood(fitlam) ≈ nullloglikelihood(fitbis)
@test r2(fitlam) ≈ r2(fitbis) atol=1e-15
@test adjr2(fitlam) ≈ adjr2(fitbis) - 0.5 atol=1e-15
@test aic(fitlam) ≈ aic(fitbis) + 2
#@test aicc(fitlam) ≈ aicc(fitbis)
@test bic(fitlam) ≈ bic(fitbis) + log(nobs(fitbis))
@test mu_estim(fitlam) ≈ mu_estim(fitbis)

## Pagel's Lambda
fitlam = phyloNetworklm(@formula(trait ~ 1), dfr, net, model = "lambda")
#@show fitlam
@test lambda_estim(fitlam) ≈ 1.24875

###############################################################################
### With shifts
###############################################################################
tree_str= "(A:2.5,((B:1,#H1:0.5::0.4):1,(C:1,(D:0.5)#H1:0.5::0.6):1):0.5);"
net = readTopology(tree_str)
preorder!(net)

## Simulate
params = ParamsBM(10, 0.1, ShiftNet(net.edge[[1,8]], [3.0, -3.0],  net))
srand(2468) # sets the seed for reproducibility, to debug potential error
sim = simulate(net, params)
Y = sim[:Tips]
## Construct regression matrix
dfr = DataFrame(trait = Y, tipNames = sim.M.tipNames)
dfr_shift = regressorShift(net.edge[[1,8]], net)
dfr = join(dfr, dfr_shift, on=:tipNames)

## Simple BM
fitShift = phyloNetworklm(trait ~ shift_1 + shift_m5, dfr, net)
@show fitShift

## Pagel's Lambda (degenerated)
fitlam = phyloNetworklm(trait ~ shift_1 + shift_m5, dfr, net, model = "lambda", fixedValue=1.0)

@test_approx_eq lambda_estim(fitlam) 1.0
@test_approx_eq coef(fitlam) coef(fitShift)
@test_approx_eq vcov(fitlam) vcov(fitShift)
@test_approx_eq nobs(fitlam) nobs(fitShift)
@test_approx_eq residuals(fitlam)[fitShift.model.ind] residuals(fitShift)
@test_approx_eq model_response(fitlam)[fitShift.model.ind] model_response(fitShift)
@test_approx_eq predict(fitlam)[fitShift.model.ind] predict(fitShift)
@test_approx_eq dof_residual(fitlam) dof_residual(fitShift)
@test_approx_eq sigma2_estim(fitlam) sigma2_estim(fitShift)
@test_approx_eq stderr(fitlam) stderr(fitShift)
@test_approx_eq confint(fitlam) confint(fitShift)
@test_approx_eq loglikelihood(fitlam) loglikelihood(fitShift)
@test_approx_eq dof(fitlam)  dof(fitShift) + 1
@test_approx_eq deviance(fitlam)  deviance(fitShift)
@test_approx_eq nulldeviance(fitlam)  nulldeviance(fitShift)
@test_approx_eq nullloglikelihood(fitlam)  nullloglikelihood(fitShift)
@test_approx_eq_eps r2(fitlam)  r2(fitShift) 1e-15
#@test_approx_eq_eps adjr2(fitlam)  adjr2(fitShift) - 0.5 1e-15
@test_approx_eq aic(fitlam)  aic(fitShift) + 2
#@test_approx_eq aicc(fitlam)  aicc(fitShift)
@test_approx_eq bic(fitlam)  bic(fitShift) + log(nobs(fitShift))
@test_approx_eq mu_estim(fitlam)  mu_estim(fitShift)

###############################################################################
#### Other Network
###############################################################################
# originally: "(((Ag,(#H1:7.159::0.056,((Ak,(E:0.08,#H2:0.0::0.004):0.023):0.078,(M:0.0)#H2:::0.996):2.49):2.214):0.026,(((((Az:0.002,Ag2:0.023):2.11,As:2.027):1.697)#H1:0.0::0.944,Ap):0.187,Ar):0.723):5.943,(P,20):1.863,165);"
# followed by changes in net.edge[?].length values to make the network ultrametric
net = readTopology("(((Ag:5,(#H1:1::0.056,((Ak:2,(E:1,#H2:1::0.004):1):1,(M:2)#H2:1::0.996):1):1):1,(((((Az:1,Ag2:1):1,As:2):1)#H1:1::0.944,Ap:4):1,Ar:5):1):1,(P:4,20:4):3,165:7);");
# plot(net, useEdgeLength = true,  showEdgeNumber=true)

#### Simulate correlated data in data frames ####
b0 = 1
b1 = 10
srand(5678)
sim = simulate(net, ParamsBM(1, 1))
A = sim[:Tips]
B = b0 + b1 * A + simulate(net,  ParamsBM(0, 0.1))[:Tips]

# With Matrices
X = hcat(ones(12), A)
fit_mat = phyloNetworklm(X, B, net)
#@show fit_mat

# Naive version (GLS)
ntaxa = length(B)
Vy = fit_mat.Vy
Vyinv = inv(Vy)
XtVyinv = X' * Vyinv
logdetVy = logdet(Vy)
betahat = inv(XtVyinv * X) * XtVyinv * B
fittedValues =  X * betahat
resids = B - fittedValues
sigma2hat = 1/ntaxa * (resids' * Vyinv * resids)
# log likelihood
loglik = - 1 / 2 * (ntaxa + ntaxa * log(2 * pi) + ntaxa * log(sigma2hat) + logdetVy)
# null version
nullX = ones(ntaxa, 1)
nullXtVyinv = nullX' * Vyinv
nullresids = B - nullX * inv(nullXtVyinv * nullX) * nullXtVyinv * B
nullsigma2hat = 1/ntaxa * (nullresids' * Vyinv * nullresids)
nullloglik = - 1 / 2 * (ntaxa + ntaxa * log(2 * pi) + ntaxa * log(nullsigma2hat) + logdetVy)
@test coef(fit_mat) ≈ betahat
@test nobs(fit_mat) ≈ ntaxa
@test residuals(fit_mat) ≈ resids
@test model_response(fit_mat) ≈ B
@test predict(fit_mat) ≈ fittedValues
@test dof_residual(fit_mat) ≈ ntaxa-length(betahat)
@test sigma2_estim(fit_mat) ≈ sigma2hat
@test loglikelihood(fit_mat) ≈ loglik
@test vcov(fit_mat) ≈ sigma2hat*ntaxa/(ntaxa-length(betahat)).*inv(XtVyinv * X)
@test stderr(fit_mat) ≈ sqrt.(diag(sigma2hat*ntaxa/(ntaxa-length(betahat)).*inv(XtVyinv * X)))
@test dof(fit_mat) ≈ length(betahat)+1
@test deviance(fit_mat) ≈ sigma2hat * ntaxa
@test nulldeviance(fit_mat) ≈ nullsigma2hat * ntaxa
@test nullloglikelihood(fit_mat) ≈ nullloglik
@test r2(fit_mat) ≈ 1-sigma2hat / nullsigma2hat atol=1e-15
@test adjr2(fit_mat) ≈ 1 - (1 - (1-sigma2hat/nullsigma2hat))*(ntaxa-1)/(ntaxa-length(betahat)) atol=1e-15
@test aic(fit_mat) ≈ -2*loglik+2*(length(betahat)+1)
@test aicc(fit_mat) ≈ -2*loglik+2*(length(betahat)+1)+2(length(betahat)+1)*((length(betahat)+1)+1)/(ntaxa-(length(betahat)+1)-1)
@test bic(fit_mat) ≈ -2*loglik+(length(betahat)+1)*log(ntaxa)

## perfect user using right format and formula
dfr = DataFrame(trait = B, pred = A, tipNames = sim.M.tipNames)
phynetlm = phyloNetworklm(@formula(trait ~ pred), dfr, net)
@show phynetlm

@test coef(phynetlm) ≈ coef(fit_mat)
@test vcov(phynetlm) ≈ vcov(fit_mat)
@test nobs(phynetlm) ≈ nobs(fit_mat)
@test residuals(phynetlm) ≈ residuals(fit_mat)
@test model_response(phynetlm) ≈ model_response(fit_mat)
@test predict(phynetlm) ≈ predict(fit_mat)
@test dof_residual(phynetlm) ≈ dof_residual(fit_mat)
@test sigma2_estim(phynetlm) ≈ sigma2_estim(fit_mat)
@test stderr(phynetlm) ≈ stderr(fit_mat)
@test confint(phynetlm) ≈ confint(fit_mat)
@test loglikelihood(phynetlm) ≈ loglikelihood(fit_mat)
@test dof(phynetlm) ≈ dof(fit_mat)
@test deviance(phynetlm) ≈ deviance(fit_mat)
@test nulldeviance(phynetlm) ≈ nulldeviance(fit_mat)
@test nullloglikelihood(phynetlm) ≈ nullloglikelihood(fit_mat)
@test r2(phynetlm) ≈ r2(fit_mat)
@test adjr2(phynetlm) ≈ adjr2(fit_mat)
@test aic(phynetlm) ≈ aic(fit_mat)
@test aicc(phynetlm) ≈ aicc(fit_mat)
@test bic(phynetlm) ≈ bic(fit_mat)

# unordered data
srand(1234)
dfr = dfr[sample(1:12, 12, replace=false), :]
fitbis = phyloNetworklm(@formula(trait ~ pred), dfr, net)

@test coef(phynetlm) ≈ coef(fitbis)
@test vcov(phynetlm) ≈ vcov(fitbis)
@test nobs(phynetlm) ≈ nobs(fitbis)
@test residuals(phynetlm)[fitbis.model.ind] ≈ residuals(fitbis)
@test model_response(phynetlm)[fitbis.model.ind] ≈ model_response(fitbis)
@test predict(phynetlm)[fitbis.model.ind] ≈ predict(fitbis)
@test dof_residual(phynetlm) ≈ dof_residual(fitbis)
@test sigma2_estim(phynetlm) ≈ sigma2_estim(fitbis)
@test stderr(phynetlm) ≈ stderr(fitbis)
@test confint(phynetlm) ≈ confint(fitbis)
@test loglikelihood(phynetlm) ≈ loglikelihood(fitbis)
@test dof(phynetlm) ≈ dof(fitbis)
@test deviance(phynetlm) ≈ deviance(fitbis)
@test nulldeviance(phynetlm) ≈ nulldeviance(fitbis)
@test nullloglikelihood(phynetlm) ≈ nullloglikelihood(fitbis)
@test r2(phynetlm) ≈ r2(fitbis)
@test adjr2(phynetlm) ≈ adjr2(fitbis)
@test aic(phynetlm) ≈ aic(fitbis)
@test aicc(phynetlm) ≈ aicc(fitbis)
@test bic(phynetlm) ≈ bic(fitbis)
@test mu_estim(phynetlm) ≈ mu_estim(fitbis)

# unnamed ordered data
dfr = DataFrame(trait = B, pred = A)
fitter = phyloNetworklm(@formula(trait ~ pred), dfr, net, no_names=true)

@test coef(phynetlm) ≈ coef(fitter)
@test vcov(phynetlm) ≈ vcov(fitter)
@test nobs(phynetlm) ≈ nobs(fitter)
@test residuals(phynetlm) ≈ residuals(fitter)
@test model_response(phynetlm) ≈ model_response(fitter)
@test predict(phynetlm) ≈ predict(fitter)
@test dof_residual(phynetlm) ≈ dof_residual(fitter)
@test sigma2_estim(phynetlm) ≈ sigma2_estim(fitter)
@test stderr(phynetlm) ≈ stderr(fitter)
@test confint(phynetlm) ≈ confint(fitter)
@test loglikelihood(phynetlm) ≈ loglikelihood(fitter)
@test dof(phynetlm) ≈ dof(fitter)
@test deviance(phynetlm) ≈ deviance(fitter)
@test nulldeviance(phynetlm) ≈ nulldeviance(fitter)
@test nullloglikelihood(phynetlm) ≈ nullloglikelihood(fitter)
@test r2(phynetlm) ≈ r2(fitter)
@test adjr2(phynetlm) ≈ adjr2(fitter)
@test aic(phynetlm) ≈ aic(fitter)
@test aicc(phynetlm) ≈ aicc(fitter)
@test bic(phynetlm) ≈ bic(fitter)

# unnamed un-ordered data
dfr = dfr[sample(1:12, 12, replace=false), :]
@test_throws ErrorException fitter = phyloNetworklm(@formula(trait ~ pred), dfr, net) # Wrong pred

### Add NAs
dfr = DataFrame(trait = B, pred = A, tipNames = tipLabels(sim))
dfr[[2, 8, 11], :pred] = NA
fitna = phyloNetworklm(@formula(trait ~ pred), dfr, net)
#@show fitna

dfr = dfr[sample(1:12, 12, replace=false), :]
fitnabis = phyloNetworklm(@formula(trait ~ pred), dfr, net)

@test coef(fitna) ≈ coef(fitnabis)
@test vcov(fitna) ≈ vcov(fitnabis)
@test nobs(fitna) ≈ nobs(fitnabis)
@test sort(residuals(fitna)) ≈ sort(residuals(fitnabis))
@test sort(model_response(fitna)) ≈ sort(model_response(fitnabis))
@test sort(predict(fitna)) ≈ sort(predict(fitnabis))
@test dof_residual(fitna) ≈ dof_residual(fitnabis)
@test sigma2_estim(fitna) ≈ sigma2_estim(fitnabis)
@test stderr(fitna) ≈ stderr(fitnabis)
@test confint(fitna) ≈ confint(fitnabis)
@test loglikelihood(fitna) ≈ loglikelihood(fitnabis)
@test dof(fitna) ≈ dof(fitnabis)
@test deviance(fitna) ≈ deviance(fitnabis)
@test nulldeviance(fitna) ≈ nulldeviance(fitnabis)
@test nullloglikelihood(fitna) ≈ nullloglikelihood(fitnabis)
@test r2(fitna) ≈ r2(fitnabis)
@test adjr2(fitna) ≈ adjr2(fitnabis)
@test aic(fitna) ≈ aic(fitnabis)
@test aicc(fitna) ≈ aicc(fitnabis)
@test bic(fitna) ≈ bic(fitnabis)

## Pagel's Lambda
fitlam = phyloNetworklm(@formula(trait ~ pred), dfr, net, model = "lambda", fixedValue = 1.0)
#@show fitlam

@test lambda_estim(fitlam) ≈ 1.0
@test coef(fitlam) ≈ coef(fitnabis)
@test vcov(fitlam) ≈ vcov(fitnabis)
@test nobs(fitlam) ≈ nobs(fitnabis)
@test residuals(fitlam) ≈ residuals(fitnabis)
@test model_response(fitlam) ≈ model_response(fitnabis)
@test predict(fitlam) ≈ predict(fitnabis)
@test dof_residual(fitlam) ≈ dof_residual(fitnabis)
@test sigma2_estim(fitlam) ≈ sigma2_estim(fitnabis)
@test stderr(fitlam) ≈ stderr(fitnabis)
@test confint(fitlam) ≈ confint(fitnabis)
@test loglikelihood(fitlam) ≈ loglikelihood(fitnabis)
@test dof(fitlam) ≈ dof(fitnabis) + 1
@test deviance(fitlam) ≈ deviance(fitnabis)
@test nulldeviance(fitlam) ≈ nulldeviance(fitnabis)
@test nullloglikelihood(fitlam) ≈ nullloglikelihood(fitnabis)
@test r2(fitlam) ≈ r2(fitnabis) atol=1e-15
@test adjr2(fitlam)-1 ≈ (adjr2(fitnabis)-1)*(nobs(fitnabis)-dof(fitnabis)+1)/(nobs(fitnabis)-dof(fitlam)+1) atol=1e-15
@test aic(fitlam) ≈ aic(fitnabis) + 2
#@test aicc(fitlam) ≈ aicc(fitnabis)
@test bic(fitlam) ≈ bic(fitnabis) + log(nobs(fitnabis))
@test mu_estim(fitlam) ≈ mu_estim(fitnabis)

## Pagel's Lambda
fitlam = phyloNetworklm(@formula(trait ~ pred), dfr, net, model = "lambda")
@show fitlam
@test lambda_estim(fitlam) ≈ 1.1135518305 atol=1e-10


### Ancestral State Reconstruction
params = ParamsBM(3, 1)
sim = simulate(net, params)
Y = sim[:Tips]
# From known parameters
ancestral_traits = ancestralStateReconstruction(net, Y, params)
# BLUP
dfr = DataFrame(trait = Y, tipNames = tipLabels(sim))
phynetlm = phyloNetworklm(@formula(trait~1), dfr, net)
blup = ancestralStateReconstruction(phynetlm)
# plot(net, blup)
@show blup

# BLUP same, using the function dirrectly
blup_bis = ancestralStateReconstruction(dfr, net)

@test expectations(blup)[:condExpectation] ≈ expectations(blup_bis)[:condExpectation]
@test expectations(blup)[:nodeNumber] ≈ expectations(blup_bis)[:nodeNumber]
@test blup.traits_tips ≈ blup_bis.traits_tips
@test blup.TipNumbers ≈ blup_bis.TipNumbers
@test predint(blup) ≈ predint(blup_bis)

dfr = DataFrame(trait = Y, tipNames = tipLabels(sim), reg = Y)
@test_throws ErrorException fitter = ancestralStateReconstruction(dfr, net) # cannot handle a predictor

# Unordered
dfr2 = dfr[sample(1:12, 12, replace=false), :]
phynetlm = phyloNetworklm(@formula(trait~1), dfr2, net)
blup2 = ancestralStateReconstruction(phynetlm)

@test expectations(blup)[:condExpectation][1:length(blup.NodeNumbers)] ≈ expectations(blup2)[:condExpectation][1:length(blup.NodeNumbers)]
@test blup.traits_tips[phynetlm.model.ind] ≈ blup2.traits_tips
@test blup.TipNumbers[phynetlm.model.ind] ≈ blup2.TipNumbers
@test predint(blup)[1:length(blup.NodeNumbers), :] ≈ predint(blup2)[1:length(blup.NodeNumbers), :]

# With unknown tips
dfr[[2, 4], :trait] = NA
phynetlm = phyloNetworklm(@formula(trait~1), dfr, net)
blup = ancestralStateReconstruction(phynetlm)
# plot(net, blup)

# Unordered
dfr2 = dfr[[1, 2, 5, 3, 4, 6, 7, 8, 9, 10, 11, 12], :]
phynetlm = phyloNetworklm(@formula(trait~1), dfr, net)
blup2 = ancestralStateReconstruction(phynetlm)

@test expectations(blup)[:condExpectation][1:length(blup.NodeNumbers)] ≈ expectations(blup2)[:condExpectation][1:length(blup.NodeNumbers)]
@test predint(blup)[1:length(blup.NodeNumbers), :] ≈ predint(blup2)[1:length(blup.NodeNumbers), :]

#################
## Data with no phylogenetic signal
#################

net = readTopology("(((Ag:5,(#H1:1::0.056,((Ak:2,(E:1,#H2:1::0.004):1):1,(M:2)#H2:1::0.996):1):1):1,(((((Az:1,Ag2:1):1,As:2):1)#H1:1::0.944,Ap:4):1,Ar:5):1):1,(P:4,20:4):3,165:7);");
# plot(net, useEdgeLength = true,  showEdgeNumber=true)

#### Simulate correlated data in data frames ####
b0 = 1
b1 = 10
srand(5678)
A = randn(size(tipLabels(net), 1))
B = b0 + b1 * A + randn(size(tipLabels(net), 1))
dfr = DataFrame(trait = B, pred = A, tipNames = tipLabels(net))

## Network
phynetlm = phyloNetworklm(@formula(trait ~ pred), dfr, net, model = "lambda")

@test lambda_estim(phynetlm) ≈ 0.5894200143 atol=1e-8

## Major Tree
tree = majorTree(net)
phynetlm = phyloNetworklm(@formula(trait ~ pred), dfr, tree, model = "lambda")

@test lambda_estim(phynetlm) ≈ 0.5903394415 atol=1e-6

############################
## Against no regressor
###########################
params = ParamsBM(10, 1)
srand(2468) # sets the seed for reproducibility, to debug potential error
sim = simulate(net, params)
Y = sim[:Tips]
phynetlm = phyloNetworklm(zeros(length(Y),0), Y, net)
#@show phynetlm
# Naive version (GLS)
ntaxa = length(Y)
Vy = phynetlm.Vy
Vyinv = inv(Vy)
logdetVy = logdet(Vy)
fittedValues =  zeros(length(Y))
resids = Y - fittedValues
sigma2hat = 1/ntaxa * (resids' * Vyinv * resids)
# log likelihood
loglik = - 1 / 2 * (ntaxa + ntaxa * log(2 * pi) + ntaxa * log(sigma2hat) + logdetVy)
# null version
nullX = ones(ntaxa, 1)
nullXtVyinv = nullX' * Vyinv
nullresids = Y - nullX * inv(nullXtVyinv * nullX) * nullXtVyinv * Y
nullsigma2hat = 1/ntaxa * (nullresids' * Vyinv * nullresids)
nullloglik = - 1 / 2 * (ntaxa + ntaxa * log(2 * pi) + ntaxa * log(nullsigma2hat) + logdetVy)

@test nobs(phynetlm) ≈ ntaxa
@test residuals(phynetlm) ≈ resids
@test model_response(phynetlm) ≈ Y
@test predict(phynetlm) ≈ fittedValues
@test dof_residual(phynetlm) ≈ ntaxa
@test sigma2_estim(phynetlm) ≈ sigma2hat
@test loglikelihood(phynetlm) ≈ loglik
@test deviance(phynetlm) ≈ sigma2hat * ntaxa
@test nulldeviance(phynetlm) ≈ nullsigma2hat * ntaxa
@test nullloglikelihood(phynetlm) ≈ nullloglik
@test r2(phynetlm) ≈ 1-sigma2hat / nullsigma2hat atol=1e-14
@test adjr2(phynetlm) ≈ 1 - (1 - (1-sigma2hat/nullsigma2hat))*(ntaxa-1)/(ntaxa) atol=1e-14
@test aic(phynetlm) ≈ -2*loglik+2*(1)
@test aicc(phynetlm) ≈ -2*loglik+2*(1)+2(1)*((1)+1)/(ntaxa-(1)-1)
@test bic(phynetlm) ≈ -2*loglik+(1)*log(ntaxa)

# with data frames
dfr = DataFrame(trait = Y, tipNames = sim.M.tipNames)
fitbis = phyloNetworklm(@formula(trait ~ -1), dfr, net)
@show fitbis
#@test coef(phynetlm) ≈ coef(fitbis)
#@test vcov(phynetlm) ≈ vcov(fitbis)
@test nobs(phynetlm) ≈ nobs(fitbis)
@test residuals(phynetlm)[fitbis.model.ind] ≈ residuals(fitbis)
@test model_response(phynetlm)[fitbis.model.ind] ≈ model_response(fitbis)
@test predict(phynetlm)[fitbis.model.ind] ≈ predict(fitbis)
@test dof_residual(phynetlm) ≈ dof_residual(fitbis)
@test sigma2_estim(phynetlm) ≈ sigma2_estim(fitbis)
#@test stderr(phynetlm) ≈ stderr(fitbis)
#@test confint(phynetlm) ≈ confint(fitbis)
@test loglikelihood(phynetlm) ≈ loglikelihood(fitbis)
#@test dof(phynetlm) ≈ dof(fitbis)
@test deviance(phynetlm) ≈ deviance(fitbis)
@test nulldeviance(phynetlm) ≈ nulldeviance(fitbis)
@test nullloglikelihood(phynetlm) ≈ nullloglikelihood(fitbis)
@test r2(phynetlm) ≈ r2(fitbis) atol=1e-15
@test adjr2(phynetlm) ≈ adjr2(fitbis) atol=1e-15
@test aic(phynetlm) ≈ aic(fitbis)
@test aicc(phynetlm) ≈ aicc(fitbis)
@test bic(phynetlm) ≈ bic(fitbis)
#@test mu_estim(phynetlm)  mu_estim(fitbis)
