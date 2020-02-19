subroutine dmft_interaction_setKanamori_mpi(MpiComm,Utensor,Uloc,Ust,Jh,Jx,Jp,test)
  implicit none
  integer                                       :: MpiComm
  real(8),dimension(:,:,:,:,:),intent(inout)    :: Utensor  ! [Norb][Norb][Norb][Norb][2]
  real(8),dimension(:),intent(in)               :: Uloc
  real(8),intent(in)                            :: Ust
  real(8),intent(in)                            :: Jh,Jx,Jp
  logical,intent(in),optional                   :: test
  !
  integer                                       :: Norb
  integer                                       :: iorb,jorb,korb,lorb
  integer                                       :: io,jo
  !
  !MPI setup:
  mpi_size  = get_size_MPI(MpiComm)
  mpi_rank =  get_rank_MPI(MpiComm)
  mpi_master= get_master_MPI(MpiComm)
  !
  !Retrieve parameters:
  call get_ctrl_var(Norb,"NORB")
  !
  !
  if(mpi_master)then
     !
     !Testing part:
     call assert_shape(Utensor,[Norb,Norb,Norb,Norb,2],"dmft_interaction_setKanamori_mpi","Umat")
     !
     Utensor=0d0
     !
     !density-density interaction: same orbital, opposite spins
     do iorb=1,Norb
        Utensor(iorb,iorb,iorb,iorb,1) = Uloc(iorb)
     enddo
     !
     !density-density interaction: different orbitals, opposite spins
     do iorb=1,Norb
        do jorb=1+iorb,Norb
           Utensor(iorb,iorb,jorb,jorb,1) = Ust
           Utensor(jorb,jorb,iorb,iorb,1) = Ust
        enddo
     enddo
     !
     !density-density interaction: different orbitals, parallel spins
     do iorb=1,Norb
        do jorb=1+iorb,Norb
           Utensor(iorb,iorb,jorb,jorb,2) = (Ust-Jh)/2.d0
           Utensor(jorb,jorb,iorb,iorb,2) = (Ust-Jh)/2.d0
        enddo
     enddo
     !
     !spin-exchange and pair-hopping
     do iorb=1,Norb
        do jorb=1+iorb,Norb
           Utensor(iorb,jorb,jorb,iorb,1) = Jx
           Utensor(jorb,iorb,iorb,jorb,1) = Jx
           Utensor(iorb,jorb,iorb,jorb,1) = Jp
           Utensor(jorb,iorb,jorb,iorb,1) = Jp
        enddo
     enddo
     !
     ! TEST-ME most probably useless due to non existence of connecting states
     if(test)then
        do iorb=1,Norb
           do jorb=1+iorb,Norb
              Utensor(iorb,jorb,jorb,iorb,2) = -(Ust-Jh)/2.d0
              Utensor(jorb,iorb,iorb,jorb,2) = -(Ust-Jh)/2.d0
           enddo
        enddo
     endif
     !
  endif
  call Bcast_Mpi(MpiComm,Utensor)
  !
end subroutine dmft_interaction_setKanamori_mpi
