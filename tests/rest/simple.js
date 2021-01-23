import { rest_service, login } from '../common'
import should from 'should'

describe('root endpoint', function () {
  before(function (done) {
    login(done)
  })

  it('returns json', function (done) {
    rest_service()
      .get('/')
      .expect('Content-Type', /json/)
      .expect(200, done)
  })
})
