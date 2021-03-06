##
## model with effects on logit/log scale
##
library(ProjectTemplate)
load.project()
invlogit=arm::invlogit
library(rstan)

# enabls --force for stallo etc.
options <- commandArgs(trailingOnly = TRUE)
if( "--force" %in% options)
  uncache.all()
bname<-tools::file_path_sans_ext(basename(this.file.name()))
mod.fname=sprintf("./src/%s.stan", bname)

n.chains=8
n.cores=8
n.iter=2000
n.warmup=1000

data=list(
  nsubj=dim(learn.jags$ACCN)[2],
  ntrials=dim(learn.jags$ACCN)[1],
  ACC=t(learn.jags$ACCN),
  pair=t(learn.jags$pairN),
  reward=t(learn.jags$rewardN),
  ACCA=t(learn.jags$ACCA),
  pairA=t(learn.jags$pairA),
  rewardA=t(learn.jags$rewardA),
  ACCB=t(learn.jags$ACCB),
  pairB=t(learn.jags$pairB),
  rewardB=t(learn.jags$rewardB)
)

## init
nsubj=data$nsubj
initfct <- function(chainix){
  nsubj=data$nsubj
  list(alphaGi=arm::logit(runif(nsubj, 0.01, 0.2)),
       alphaLi=arm::logit(runif(nsubj, 0.01, 0.2)),     
       logbeta=log(runif(nsubj,0.01, 0.4)),
       mu_alphaG=rnorm(1,0,0.1),
       mu_alphaL=rnorm(1,0,0.1),
       sig_alpha=0.2,
       mu_beta=rnorm(1,0,0.1),
       sig_beta=0.2,
       effAalphaG=rnorm(1,0,0.1),
       effBalphaG=rnorm(1,0,0.1),
       effAalphaL=rnorm(1,0,0.1),
       effBalphaL=rnorm(1,0,0.1),
       effAbeta=rnorm(1,0,0.1),
       effBbeta=rnorm(1,0,0.1)
  )
}
#stop()
if(is.cached.var("fit")){
  printf("WARNING: loading variables from cache\n")
  fit=load.cache.var("fit")
} else {
  mod <- stan(mod.fname, data = data, chains = 0)

  start.time = proc.time()
  # parallel or single-core fitting
  if(n.cores==1){
    fit = stan(fit = mod, data = data, chains = n.chains, iter = n.iter, warmup = n.warmup, init=initfct)
    #fit = pstan(fit = mod, data = data, chains = 2, iter = n.iter, warmup = n.warmup)#, init=initfct)
  } else {
    
    library(rstanmulticore)
    inits=lapply(1:n.chains, initfct)
    fit = pstan(fit = mod, data = data, chains = n.chains, iter = n.iter, warmup = n.warmup, init=inits)
    
#     library(parallel)
#     sflist <- mclapply(1:n.chains, mc.cores = n.cores, 
#                        function(i) stan(fit = mod, data = data, 
#                                         seed = i, iter = n.iter, warmup = n.warmup,
#                                         chains = 1, chain_id = i, 
#                                         refresh = -1))
#     fit <- sflist2stanfit(sflist)
  }
  tellmedone()
  end.time = proc.time()
  show("Time taken for sampling")
  show(end.time-start.time)
  
  cache.var('fit')
}

print(fit)  
##
##=========================================================================================================================
##


#plot(fit)
#traceplot(fit)
#waicp(fit)

m <- as.matrix(fit)
vars=colnames(m)
# 
# 
# 
means <- m[,str_detect(vars, 'mu')]
dotplot(means)+ggtitle("means on logit/log scales")#+xlim(0,.3)
means.org <- cbind( alphaG=invlogit(means[,'mu_alphaG']),
                    alphaL=invlogit(means[,'mu_alphaL']), 
                    beta=exp(means[,'mu_beta']) )
dotplot(means.org)+ggtitle('means on original scales')+xlim(0,.5)
 
dotplot(m[,str_detect(vars, 'eff')])+ggtitle("Effect on logit scale")+geom_vline(x=0, color='red')
 
orgscale.effects <- cbind( 
   effAalphaG=invlogit(mean(m[,'mu_alphaG'])+m[,'effAalphaG'])-invlogit(mean(m[,'mu_alphaG'])),
   effBalphaG=invlogit(mean(m[,'mu_alphaG'])+m[,'effBalphaG'])-invlogit(mean(m[,'mu_alphaG'])),
   effAalphaL=invlogit(mean(m[,'mu_alphaL'])+m[,'effAalphaL'])-invlogit(mean(m[,'mu_alphaL'])),
   effBalphaL=invlogit(mean(m[,'mu_alphaL'])+m[,'effBalphaL'])-invlogit(mean(m[,'mu_alphaL'])),
   effAbeta=exp(mean(m[,'mu_beta'])+m[,'effAbeta'])-exp(mean(m[,'mu_beta'])),
   effBbeta=exp(mean(m[,'mu_beta'])+m[,'effBbeta'])-exp(mean(m[,'mu_beta']))
)
dotplot(orgscale.effects)+geom_vline(x=0, color='red')+ggtitle("Effect on original scale at mean")

alpha<-(extract(fit, 'alphaG')[[1]])
colnames(alpha) <- 1:nsubj
alphaA<-(extract(fit, 'alphaGA')[[1]])
colnames(alphaA) <- 1:nsubj
alphaB<-(extract(fit, 'alphaBG')[[1]])
colnames(alphaB) <- 1:nsubj
dotplot(alpha, alphaA, alphaB)
# 


## paper plots
##-----------------------------------------------------------------
alphaG<-(extract(fit, 'alphaG')[[1]])
colnames(alphaG) <- 1:nsubj
p1 <- cbind(subj=1:nsubj,
            mean=apply(alphaG, 2, mean),
            hdi=hdi(alphaG)) %>% data.frame %>%
  ggplot(aes(x=subj,y=mean,ymin=lower,ymax=upper))+geom_errorbar(width=0.1)+geom_point()+theme_bw()+
  geom_hline(y=invlogit(mean(m[,'mu_alphaG'])))+
  geom_hline(y=invlogit(hdi(m[,'mu_alphaG'])[1]), linetype=2)+
  geom_hline(y=invlogit(hdi(m[,'mu_alphaG'])[2]), linetype=2)+xlab("subject number")+ylab(expression(alpha["G"]))+
  ylim(0,1)

alphaL<-(extract(fit, 'alphaL')[[1]])
colnames(alphaL) <- 1:nsubj
p2 <- cbind(subj=1:nsubj,
            mean=apply(alphaL, 2, mean),
            hdi=hdi(alphaL)) %>% data.frame %>%
  ggplot(aes(x=subj,y=mean,ymin=lower,ymax=upper))+geom_errorbar(width=0.1)+geom_point()+theme_bw()+
  geom_hline(y=invlogit(mean(m[,'mu_alphaL'])))+
  geom_hline(y=invlogit(hdi(m[,'mu_alphaL'])[1]), linetype=2)+
  geom_hline(y=invlogit(hdi(m[,'mu_alphaL'])[2]), linetype=2)+xlab("subject number")+ylab(expression(alpha["L"]))+
  ylim(0,1)

beta<-(extract(fit, 'beta')[[1]])
colnames(beta) <- 1:nsubj
p3 <- cbind(subj=1:nsubj,
            mean=apply(beta, 2, mean),
            hdi=hdi(beta)) %>% data.frame %>%
  ggplot(aes(x=subj,y=mean,ymin=lower,ymax=upper))+geom_errorbar(width=0.1)+geom_point()+theme_bw()+
  geom_hline(y=invlogit(mean(m[,'mu_beta'])))+
  geom_hline(y=invlogit(hdi(m[,'mu_beta'])[1]), linetype=2)+
  geom_hline(y=invlogit(hdi(m[,'mu_beta'])[2]), linetype=2)+xlab("subject number")+ylab(expression(beta))+
  ylim(0,1)

a=multiplot(p1,p2,p3,cols=3)

## table for effects on original scale, assuming position at baseline mean
e=cbind(mean=apply(orgscale.effects, 2, mean),
        sd=apply(orgscale.effects, 2, sd),
      hdi=hdi(orgscale.effects))
print(e, digits=3)

## table of effects on logit-scale
effects=m[,str_detect(vars, 'eff')]
e2=cbind(mean=apply(effects, 2, mean),
        sd=apply(effects, 2, sd),
        hdi=hdi(effects))
print(e2, digits=3)


## dotplot for paper
lwd=3.5
pch=19
cex=1.5
labels=c("LU", "HU")

par(mfrow=c(3,2),mar = c(3,5,3,1))
plot( e2[1:2,1], 1:2, axes=F, ann=F, xlim=c(0,1.5), ylim=c(0.8,2.2), pch=pch, cex=cex)
lines( e2[1,3:4],c(1,1), lwd=lwd)
lines( e2[2,3:4],c(2,2), lwd=lwd)
lines( c(0,0), c(.8,2.2), col="red")
axis(1)
axis(2,at=c(1,2), labels=labels)
mtext(expression(paste("effect ", alpha[G])), side=2, line=3)
title('logit-scale')

plot( e[1:2,1], 1:2, axes=F, ann=F, xlim=c(0,.2), ylim=c(0.8,2.2), pch=pch, cex=cex)
lines( e[1,3:4],c(1,1), lwd=lwd)
lines( e[2,3:4],c(2,2), lwd=lwd)
lines( c(0,0), c(.8,2.2), col="red")
axis(1)
axis(2,at=c(1,2), labels=labels)
title('original scale at mean')

plot( e2[3:4,1], 1:2, axes=F, ann=F, xlim=c(-1.5,0), ylim=c(0.8,2.2), pch=pch, cex=cex)
lines( e2[3,3:4],c(1,1), lwd=lwd)
lines( e2[4,3:4],c(2,2), lwd=lwd)
lines( c(0,0), c(.8,2.2), col="red")
axis(1)
axis(2,at=c(1,2), labels=labels)
mtext(expression(paste("effect ", alpha[L])), side=2, line=3)

plot( e[3:4,1], 1:2, axes=F, ann=F, xlim=c(-.05,0), ylim=c(0.8,2.2), pch=pch, cex=cex)
lines( e[3,3:4],c(1,1), lwd=lwd)
lines( e[4,3:4],c(2,2), lwd=lwd)
lines( c(0,0), c(.8,2.2), col="red")
axis(1)
axis(2,at=c(1,2), labels=labels)

plot( e2[5:6,1], 1:2, axes=F, ann=F, xlim=c(-.2,.2), ylim=c(0.8,2.2), pch=pch, cex=cex)
lines( e2[5,3:4],c(1,1), lwd=lwd)
lines( e2[6,3:4],c(2,2), lwd=lwd)
lines( c(0,0), c(.8,2.2), col="red")
axis(1)
axis(2,at=c(1,2), labels=labels)
mtext(expression(paste("effect ", beta)), side=2, line=3)

plot( e[5:6,1], 1:2, axes=F, ann=F, xlim=c(-.05,0.05), ylim=c(0.8,2.2), pch=pch, cex=cex)
lines( e[5,3:4],c(1,1), lwd=lwd)
lines( e[6,3:4],c(2,2), lwd=lwd)
lines( c(0,0), c(.8,2.2), col="red")
axis(1)
axis(2,at=c(1,2), labels=labels)


stop()

## posterior predictive plots for most difficult pair
## ------------------------------------------------------
alphaG<-(extract(fit, 'alphaG')[[1]])
alphaL<-(extract(fit, 'alphaL')[[1]])
beta  <-(extract(fit, 'beta')[[1]])
alphaGA<-(extract(fit, 'alphaGA')[[1]])
alphaLA<-(extract(fit, 'alphaLA')[[1]])
betaA  <-(extract(fit, 'betaA')[[1]])
alphaGB<-(extract(fit, 'alphaGB')[[1]])
alphaLB<-(extract(fit, 'alphaLB')[[1]])
betaB  <-(extract(fit, 'betaB')[[1]])

subjs=levels(learn$Participant)
show.pair=1
nsim=2
mul=1.5
pdf(file=sprintf("graphs/%s_ppred.pdf", bname), height=15*mul, width=8*mul)
par(mfrow=c(length(subjs),3), mar = c(0.5,2,0.2,0.2))

for( i in 1:length(subjs)){
  d<-learn %>% filter(Participant==subjs[i], ACC>=0) %>% group_by(condition,pair) %>% mutate(trial=1:n()) %>% ungroup %>% data.frame
  
  ## N
  ix=d$condition=="N"
  with(d, plot(trial[pair==show.pair & ix], ACC[pair==show.pair & ix],  pch=".", col='grey', cex=5, axes=F, ann=F))
  box()
  mtext(subjs[i], side=2, line=0.4)
  if(i==1) mtext("N", side=3, line=0.5)
  for(j in 1:nsim){
    rix=sample(1:dim(alphaG)[1], 1)
    d$pa<-NA
    d$pa[ix]=paqlearning.posneg(alphaG[rix,i], alphaL[rix,i], beta[rix,i], d$ACC[ix], d$pair[ix], d$reward[ix])
    with(d, lines(trial[pair==show.pair & ix], pa[pair==show.pair & ix], col="grey"))
  }
  d$pa[ix]=paqlearning.posneg(mean(alphaG[,i]), mean(alphaL[,i]), mean(beta[,i]), d$ACC[ix], d$pair[ix], d$reward[ix])
  with(d, lines(trial[pair==show.pair & ix], pa[pair==show.pair & ix], col="red"))
  
  ## A
  ix=d$condition=="A"
  with(d, plot(trial[pair==show.pair & ix], ACC[pair==show.pair & ix],  pch=".", col='grey', cex=5, axes=F, ann=F))
  box()
  if(i==1) mtext("A", side=3, line=0.5)

  for(j in 1:nsim){
    rix=sample(1:dim(alphaGA)[1], 1)
    d$pa<-NA
    d$pa[ix]=paqlearning.posneg(alphaGA[rix,i], alphaLA[rix,i], betaA[rix,i], d$ACC[ix], d$pair[ix], d$reward[ix])
    with(d, lines(trial[pair==show.pair & ix], pa[pair==show.pair & ix], col="grey"))
  }
  d$pa[ix]=paqlearning.posneg(mean(alphaGA[,i]), mean(alphaLA[,i]), mean(betaA[,i]), d$ACC[ix], d$pair[ix], d$reward[ix])
  with(d, lines(trial[pair==show.pair & ix], pa[pair==show.pair & ix], col="red"))

  ## B
  ix=d$condition=="B"
  with(d, plot(trial[pair==show.pair & ix], ACC[pair==show.pair & ix],  pch=".", col='grey', cex=5, axes=F, ann=F))
  box()
  if(i==1) mtext("B", side=3, line=0.5)
  
  for(j in 1:nsim){
    rix=sample(1:dim(alphaGB)[1], 1)
    d$pa<-NA
    d$pa[ix]=paqlearning.posneg(alphaGB[rix,i], alphaLB[rix,i], betaB[rix,i], d$ACC[ix], d$pair[ix], d$reward[ix])
    with(d, lines(trial[pair==show.pair & ix], pa[pair==show.pair & ix], col="grey"))
  }
  d$pa[ix]=paqlearning.posneg(mean(alphaGB[,i]), mean(alphaLB[,i]), mean(betaB[,i]), d$ACC[ix], d$pair[ix], d$reward[ix])
  with(d, lines(trial[pair==show.pair & ix], pa[pair==show.pair & ix], col="red"))
  
}
dev.off()


##
##
group.pars=extract(fit, c("mu_alphaG", 'mu_alphaL', "mu_beta"))
cbind(mean=unlist(lapply(group.pars, function(x){mean(invlogit(x))})),
      sd=unlist(lapply(group.pars, function(x){sd(invlogit(x))})),
      lower=unlist(lapply(group.pars, function(x){hdi(as.vector(invlogit(x)))[1]})),
      upper=unlist(lapply(group.pars, function(x){hdi(as.vector(invlogit(x)))[2]}))
)


# odds-ratio for effect on alphaG B>A 
hist(m[,'effBalphaG']-m[,'effAalphaG'])
ppos=sum( (m[,'effBalphaG']-m[,'effAalphaG'])>0 )/dim(m)[1]
ppos/(1-ppos)

hist(m[,'effBalphaL']-m[,'effAalphaL'])
ppos=sum( (m[,'effBalphaL']-m[,'effAalphaL'])>0 )/dim(m)[1]
ppos
